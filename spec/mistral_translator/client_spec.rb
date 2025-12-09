# frozen_string_literal: true

RSpec.describe MistralTranslator::Client do
  let(:client) { described_class.new(api_key: "test_api_key") }
  let(:prompt) { "Translate 'Hello' to French" }
  let(:context) { { from_locale: "en", to_locale: "fr", attempt: 0 } }

  before do
    # Reset configuration pour les tests
    MistralTranslator.reset_configuration!
    MistralTranslator.configure { |c| c.api_key = "test_api_key" }
  end

  describe "#initialize" do
    it "uses provided api_key" do
      custom_client = described_class.new(api_key: "custom_key")
      expect(custom_client.instance_variable_get(:@api_key)).to eq("custom_key")
    end

    it "uses configuration api_key when none provided" do
      MistralTranslator.configure { |c| c.api_key = "config_key" }
      default_client = described_class.new
      expect(default_client.instance_variable_get(:@api_key)).to eq("config_key")
    end

    it "raises error when no api_key available" do
      MistralTranslator.reset_configuration!
      expect { described_class.new }.to raise_error(MistralTranslator::ConfigurationError)
    end
  end

  describe "#complete" do
    let(:valid_response_body) do
      {
        choices: [
          {
            message: {
              content: '{"content": {"target": "Bonjour"}}'
            }
          }
        ]
      }
    end

    context "with successful response" do
      before do
        stub_mistral_api(response_body: valid_response_body)
      end

      it "returns the content from API response" do
        result = client.complete(prompt, context: context)
        expect(result).to eq('{"content": {"target": "Bonjour"}}')
      end

      it "sends correct request headers" do
        client.complete(prompt, context: context)

        expect(WebMock).to have_requested(:post, "https://api.mistral.ai/v1/chat/completions")
          .with(
            headers: {
              "Authorization" => "Bearer test_api_key",
              "Content-Type" => "application/json",
              "User-Agent" => "mistral-translator-gem/#{MistralTranslator::VERSION}"
            }
          )
      end

      it "sends correct request body" do
        client.complete(prompt, max_tokens: 100, temperature: 0.7, context: context)

        expect(WebMock).to have_requested(:post, "https://api.mistral.ai/v1/chat/completions")
          .with(
            body: {
              model: "mistral-small",
              messages: [{ role: "user", content: prompt }],
              max_tokens: 100,
              temperature: 0.7
            }.to_json
          )
      end

      # Nouveaux tests pour les callbacks
      context "with callbacks enabled" do
        before do
          start_callback = double("start_callback")
          complete_callback = double("complete_callback")
          allow(start_callback).to receive(:call).with(any_args)
          allow(complete_callback).to receive(:call).with(any_args)

          MistralTranslator.configure do |config|
            config.enable_metrics = true
            config.on_translation_start = start_callback
            config.on_translation_complete = complete_callback
          end
        end

        it "triggers translation start callback" do
          expect(MistralTranslator.configuration.on_translation_start)
            .to receive(:call).with("en", "fr", prompt.length, anything)

          client.complete(prompt, context: context)
        end

        it "triggers translation complete callback" do
          expect(MistralTranslator.configuration.on_translation_complete)
            .to receive(:call).with("en", "fr", prompt.length, anything, anything)

          client.complete(prompt, context: context)
        end
      end

      context "without context" do
        it "handles missing context gracefully" do
          expect { client.complete(prompt) }.not_to raise_error
        end
      end
    end

    context "with API errors" do
      before do
        error_callback = double("error_callback")
        allow(error_callback).to receive(:call).with(any_args)

        MistralTranslator.configure do |config|
          config.on_translation_error = error_callback
        end
      end

      it "raises AuthenticationError for 401 status" do
        stub_mistral_api(response_body: invalid_api_key_response, status: 401)

        expect { client.complete(prompt, context: context) }.to raise_error(
          MistralTranslator::AuthenticationError,
          "Invalid API key"
        )
      end

      it "raises ApiError for 500 status" do
        stub_mistral_api(
          response_body: { error: "Internal server error" },
          status: 500
        )

        expect { client.complete(prompt, context: context) }.to raise_error(
          MistralTranslator::ApiError,
          /Server error \(500\)/
        )
      end

      it "raises InvalidResponseError for empty content" do
        stub_mistral_api(
          response_body: { choices: [{ message: { content: nil } }] }
        )

        expect { client.complete(prompt, context: context) }.to raise_error(
          MistralTranslator::InvalidResponseError,
          "No content in API response"
        )
      end

      it "triggers error callback on JSON parsing error" do
        stub_mistral_api(response_body: "invalid json")

        expect(MistralTranslator.configuration.on_translation_error)
          .to receive(:call).with("en", "fr", anything, 0, anything)

        expect { client.complete(prompt, context: context) }.to raise_error(
          MistralTranslator::InvalidResponseError
        )
      end

      it "raises InvalidResponseError for malformed JSON" do
        stub_mistral_api(response_body: "invalid json")

        expect { client.complete(prompt, context: context) }.to raise_error(
          MistralTranslator::InvalidResponseError,
          /Invalid JSON in API response/
        )
      end
    end

    context "with rate limiting" do
      before do
        rate_limit_callback = double("rate_limit_callback")
        allow(rate_limit_callback).to receive(:call).with(any_args)

        MistralTranslator.configure do |config|
          config.on_rate_limit = rate_limit_callback
        end
      end

      it "retries on rate limit and succeeds" do
        # Premier appel : rate limit
        stub_request(:post, "https://api.mistral.ai/v1/chat/completions")
          .to_return(status: 429, body: rate_limit_response.to_json)
          .then
          .to_return(status: 200, body: valid_response_body.to_json)

        expect(MistralTranslator.configuration.on_rate_limit)
          .to receive(:call).with("en", "fr", 2, 1, anything)

        result = client.complete(prompt, context: context)
        expect(result).to eq('{"content": {"target": "Bonjour"}}')
        expect(WebMock).to have_requested(:post, "https://api.mistral.ai/v1/chat/completions").twice
      end

      it "raises RateLimitError after max retries" do
        # Configuration temporaire avec moins de retries pour accélérer le test
        original_retry_delays = MistralTranslator.configuration.retry_delays
        MistralTranslator.configure { |c| c.retry_delays = [0.01, 0.01] } # 2 retries rapides

        stub_mistral_api(response_body: rate_limit_response, status: 429)

        # Le callback rate_limit sera appelé plusieurs fois pendant les retries
        expect(MistralTranslator.configuration.on_rate_limit)
          .to receive(:call).with(any_args).at_least(:once)

        expect { client.complete(prompt, context: context) }.to raise_error(
          MistralTranslator::RateLimitError,
          /API rate limit exceeded after \d+ retries/
        )

        # Restaurer la configuration originale
        MistralTranslator.configure { |c| c.retry_delays = original_retry_delays }
      end
    end

    context "with network errors" do
      it "raises ApiError for timeout" do
        stub_request(:post, "https://api.mistral.ai/v1/chat/completions")
          .to_timeout

        expect { client.complete(prompt, context: context) }.to raise_error(
          MistralTranslator::ApiError,
          /Request timeout/
        )
      end
    end
  end

  describe "#chat" do
    let(:valid_response_body) do
      {
        choices: [
          {
            message: {
              content: "Simple response without JSON"
            }
          }
        ]
      }
    end

    before do
      start_callback = double("start_callback")
      complete_callback = double("complete_callback")
      error_callback = double("error_callback")
      allow(start_callback).to receive(:call).with(any_args)
      allow(complete_callback).to receive(:call).with(any_args)
      allow(error_callback).to receive(:call).with(any_args)

      MistralTranslator.configure do |config|
        config.enable_metrics = true
        config.on_translation_start = start_callback
        config.on_translation_complete = complete_callback
        config.on_translation_error = error_callback
      end
    end

    it "returns raw content without parsing" do
      stub_mistral_api(response_body: valid_response_body)

      expect(MistralTranslator.configuration.on_translation_start)
        .to receive(:call).with("en", "fr", prompt.length, anything)
      expect(MistralTranslator.configuration.on_translation_complete)
        .to receive(:call).with("en", "fr", prompt.length, anything, anything)

      result = client.chat(prompt, context: context)
      expect(result).to eq("Simple response without JSON")
    end

    it "triggers error callback for malformed JSON response" do
      stub_mistral_api(response_body: "invalid json")

      expect(MistralTranslator.configuration.on_translation_error)
        .to receive(:call).with("en", "fr", anything, 0, anything)

      expect { client.chat(prompt, context: context) }.to raise_error(
        MistralTranslator::InvalidResponseError,
        /JSON parse error/
      )
    end
  end

  # Nouveaux tests pour la fonctionnalité batch
  describe "#translate_batch" do
    let(:batch_requests) do
      [
        { prompt: "Translate 'Hello'", from: "en", to: "fr", index: 0, original_text: "Hello" },
        { prompt: "Translate 'Goodbye'", from: "en", to: "fr", index: 1, original_text: "Goodbye" }
      ]
    end

    let(:successful_response) { '{"content": {"target": "Bonjour"}}' }

    before do
      batch_callback = double("batch_callback")
      allow(batch_callback).to receive(:call).with(any_args)

      MistralTranslator.configure do |config|
        config.on_batch_complete = batch_callback
      end

      allow(client).to receive(:complete).and_return(successful_response)
    end

    it "processes batch requests" do
      result = client.translate_batch(batch_requests, batch_size: 2)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.first[:success]).to be true
      expect(result.first[:result]).to eq(successful_response)
    end

    it "triggers batch complete callback" do
      expect(MistralTranslator.configuration.on_batch_complete)
        .to receive(:call).with(2, anything, 2, 0)

      client.translate_batch(batch_requests, batch_size: 2)
    end

    it "handles errors in batch" do
      allow(client).to receive(:complete)
        .and_raise(MistralTranslator::ApiError, "API Error")

      result = client.translate_batch(batch_requests, batch_size: 2)

      expect(result.first[:success]).to be false
      expect(result.first[:error]).to eq("API Error")
    end

    it "splits large batches correctly" do
      large_batch = Array.new(12) do |i|
        { prompt: "Translate #{i}", from: "en", to: "fr", index: i, original_text: "Text #{i}" }
      end

      # Avec batch_size=5, on s'attend à 3 batches (5, 5, 2)
      expect(client).to receive(:sleep).at_least(:once) # Entre les batches

      result = client.translate_batch(large_batch, batch_size: 5)
      expect(result.length).to eq(12)
    end

    it "adds delays between batches but not within batches" do
      large_batch = Array.new(6) do |i|
        { prompt: "Translate #{i}", from: "en", to: "fr", index: i, original_text: "Text #{i}" }
      end

      # Avec batch_size=3, on s'attend à 2 batches, donc 1 sleep
      expect(client).to receive(:sleep).once.with(2)

      client.translate_batch(large_batch, batch_size: 3)
    end
  end

  describe "private methods" do
    describe "#build_request_body" do
      it "builds basic request body" do
        body = client.send(:build_request_body, prompt, nil, nil)

        expect(body).to eq({
                             model: "mistral-small",
                             messages: [{ role: "user", content: prompt }]
                           })
      end

      it "includes optional parameters when provided" do
        body = client.send(:build_request_body, prompt, 100, 0.7)

        expect(body).to include(
          max_tokens: 100,
          temperature: 0.7
        )
      end
    end

    describe "#headers" do
      it "includes all required headers" do
        headers = client.send(:headers)

        expect(headers).to include(
          "Authorization" => "Bearer test_api_key",
          "Content-Type" => "application/json",
          "User-Agent" => "mistral-translator-gem/#{MistralTranslator::VERSION}"
        )
      end
    end

    describe "#rate_limit_exceeded?" do
      it "detects rate limit by status code" do
        response = double(code: "429", body: "")
        expect(client.send(:rate_limit_exceeded?, response)).to be true
      end

      it "detects rate limit by message content" do
        response = double(code: "200", body: "rate limit exceeded")
        expect(client.send(:rate_limit_exceeded?, response)).to be true
      end

      it "returns false for normal responses" do
        response = double(code: "200", body: "normal response")
        expect(client.send(:rate_limit_exceeded?, response)).to be false
      end
    end

    describe "#process_batch_slice" do
      let(:batch_slice) do
        [
          { prompt: "Hello", from: "en", to: "fr" },
          { prompt: "Goodbye", from: "en", to: "fr" }
        ]
      end

      it "processes successful requests" do
        allow(client).to receive(:complete).and_return("Bonjour", "Au revoir")

        result = client.send(:process_batch_slice, batch_slice)

        expect(result[:success_count]).to eq(2)
        expect(result[:error_count]).to eq(0)
        expect(result[:results].first[:success]).to be true
        expect(result[:results].first[:result]).to eq("Bonjour")
      end

      it "handles mixed success and errors" do
        call_count = 0
        allow(client).to receive(:complete) do |*_args|
          call_count += 1
          raise MistralTranslator::ApiError, "Error" unless call_count == 1

          "Bonjour"
        end

        result = client.send(:process_batch_slice, batch_slice)

        expect(result[:success_count]).to eq(1)
        expect(result[:error_count]).to eq(1)
        expect(result[:results].first[:success]).to be true
        expect(result[:results].last[:success]).to be false
        expect(result[:results].last[:error]).to eq("Error")
      end
    end

    describe "#http_pool" do
      it "creates Net::HTTP::Persistent pool" do
        pool = client.send(:http_pool)
        expect(pool).to be_a(Net::HTTP::Persistent)
      end

      it "configures pool with correct timeouts" do
        pool = client.send(:http_pool)
        expect(pool.read_timeout).to eq(60)
        expect(pool.idle_timeout).to eq(30)
        expect(pool.max_requests).to eq(100)
      end

      it "uses SSL timeout from configuration" do
        MistralTranslator.configure { |c| c.ssl_timeout = 45 }

        # Reset pool to pick up new config
        client.instance_variable_set(:@http_pool, nil)

        pool = client.send(:http_pool)
        expect(pool.open_timeout).to eq(45)
      end

      it "reuses the same pool instance" do
        pool1 = client.send(:http_pool)
        pool2 = client.send(:http_pool)
        expect(pool1).to be(pool2)
      end
    end

    describe "#configure_ssl" do
      let(:pool) { Net::HTTP::Persistent.new(name: "test") }

      it "sets verify_mode to VERIFY_PEER by default" do
        client.send(:configure_ssl, pool)
        expect(pool.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
      end

      it "sets verify_mode to VERIFY_NONE when configured" do
        MistralTranslator.configure { |c| c.ssl_verify_mode = :none }
        client.send(:configure_ssl, pool)
        expect(pool.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
      end

      it "accepts OpenSSL constant directly" do
        MistralTranslator.configure { |c| c.ssl_verify_mode = OpenSSL::SSL::VERIFY_PEER }
        client.send(:configure_ssl, pool)
        expect(pool.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
      end

      it "sets CA file when configured" do
        MistralTranslator.configure { |c| c.ssl_ca_file = "/path/to/ca.pem" }
        client.send(:configure_ssl, pool)
        expect(pool.ca_file).to eq("/path/to/ca.pem")
      end

      it "sets CA path when configured" do
        MistralTranslator.configure { |c| c.ssl_ca_path = "/path/to/certs" }
        client.send(:configure_ssl, pool)
        expect(pool.ca_path).to eq("/path/to/certs")
      end

      it "does not set CA file or path when nil" do
        MistralTranslator.configure do |c|
          c.ssl_ca_file = nil
          c.ssl_ca_path = nil
        end

        client.send(:configure_ssl, pool)
        expect(pool.ca_file).to be_nil
        expect(pool.ca_path).to be_nil
      end
    end
  end
end

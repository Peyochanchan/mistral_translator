# frozen_string_literal: true

RSpec.describe MistralTranslator::Client do
  let(:client) { described_class.new(api_key: "test_api_key") }
  let(:prompt) { "Translate 'Hello' to French" }

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
        result = client.complete(prompt)
        expect(result).to eq('{"content": {"target": "Bonjour"}}')
      end

      it "sends correct request headers" do
        client.complete(prompt)

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
        client.complete(prompt, max_tokens: 100, temperature: 0.7)

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
    end

    context "with API errors" do
      it "raises AuthenticationError for 401 status" do
        stub_mistral_api(response_body: invalid_api_key_response, status: 401)

        expect { client.complete(prompt) }.to raise_error(
          MistralTranslator::AuthenticationError,
          "Invalid API key"
        )
      end

      it "raises ApiError for 500 status" do
        stub_mistral_api(
          response_body: { error: "Internal server error" },
          status: 500
        )

        expect { client.complete(prompt) }.to raise_error(
          MistralTranslator::ApiError,
          /Server error \(500\)/
        )
      end

      it "raises InvalidResponseError for empty content" do
        stub_mistral_api(
          response_body: { choices: [{ message: { content: nil } }] }
        )

        expect { client.complete(prompt) }.to raise_error(
          MistralTranslator::InvalidResponseError,
          "No content in API response"
        )
      end

      it "raises InvalidResponseError for malformed JSON" do
        stub_mistral_api(response_body: "invalid json")

        expect { client.complete(prompt) }.to raise_error(
          MistralTranslator::InvalidResponseError,
          /Invalid JSON in API response/
        )
      end
    end

    context "with rate limiting" do
      it "retries on rate limit and succeeds" do
        # Premier appel : rate limit
        stub_request(:post, "https://api.mistral.ai/v1/chat/completions")
          .to_return(status: 429, body: rate_limit_response.to_json)
          .then
          .to_return(status: 200, body: valid_response_body.to_json)

        result = client.complete(prompt)
        expect(result).to eq('{"content": {"target": "Bonjour"}}')
        expect(WebMock).to have_requested(:post, "https://api.mistral.ai/v1/chat/completions").twice
      end

      it "raises RateLimitError after max retries" do
        stub_mistral_api(response_body: rate_limit_response, status: 429)

        expect { client.complete(prompt) }.to raise_error(
          MistralTranslator::RateLimitError,
          /API rate limit exceeded after \d+ retries/
        )
      end
    end

    context "with network errors" do
      it "raises ApiError for timeout" do
        stub_request(:post, "https://api.mistral.ai/v1/chat/completions")
          .to_timeout

        expect { client.complete(prompt) }.to raise_error(
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

    it "returns raw content without parsing" do
      stub_mistral_api(response_body: valid_response_body)

      result = client.chat(prompt)
      expect(result).to eq("Simple response without JSON")
    end

    it "raises InvalidResponseError for malformed JSON response" do
      stub_mistral_api(response_body: "invalid json")

      expect { client.chat(prompt) }.to raise_error(
        MistralTranslator::InvalidResponseError,
        /JSON parse error/
      )
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
  end
end

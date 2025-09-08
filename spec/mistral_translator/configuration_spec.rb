# frozen_string_literal: true

RSpec.describe MistralTranslator::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.api_key).to be_nil
      expect(config.api_url).to eq("https://api.mistral.ai")
      expect(config.model).to eq("mistral-small")
      expect(config.default_max_tokens).to be_nil
      expect(config.default_temperature).to be_nil
      expect(config.retry_delays).to eq([2, 4, 8, 16, 32, 64, 128, 256, 512, 1024])

      # Nouvelles valeurs par défaut pour les callbacks
      expect(config.on_translation_start).to be_nil
      expect(config.on_translation_complete).to be_nil
      expect(config.on_translation_error).to be_nil
      expect(config.on_rate_limit).to be_nil
      expect(config.on_batch_complete).to be_nil
      expect(config.enable_metrics).to be false
    end
  end

  describe "#api_key!" do
    context "when api_key is set" do
      before { config.api_key = "test_key" }

      it "returns the api key" do
        expect(config.api_key!).to eq("test_key")
      end
    end

    context "when api_key is nil" do
      it "raises ConfigurationError" do
        expect { config.api_key! }.to raise_error(
          MistralTranslator::ConfigurationError,
          /API key is required/
        )
      end
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting api_key" do
      config.api_key = "new_key"
      expect(config.api_key).to eq("new_key")
    end

    it "allows setting and getting api_url" do
      config.api_url = "https://custom.api.url"
      expect(config.api_url).to eq("https://custom.api.url")
    end

    it "allows setting and getting model" do
      config.model = "mistral-large"
      expect(config.model).to eq("mistral-large")
    end

    it "allows setting and getting retry_delays" do
      custom_delays = [1, 2, 4]
      config.retry_delays = custom_delays
      expect(config.retry_delays).to eq(custom_delays)
    end

    # Nouveaux tests pour les callbacks
    it "allows setting callbacks" do
      callback = ->(_from, _to, _length, _timestamp) { puts "callback" }
      config.on_translation_start = callback
      expect(config.on_translation_start).to eq(callback)
    end

    it "allows enabling metrics" do
      config.enable_metrics = true
      expect(config.enable_metrics).to be true
    end
  end

  describe "callback triggers" do
    before { config.enable_metrics = true }

    describe "#trigger_translation_start" do
      it "calls the callback when set" do
        callback_called = false
        config.on_translation_start = ->(_from, _to, _length, _timestamp) { callback_called = true }

        config.trigger_translation_start("en", "fr", 100)
        expect(callback_called).to be true
      end

      it "updates metrics when enabled" do
        config.trigger_translation_start("en", "fr", 100)

        metrics = config.metrics
        expect(metrics[:total_translations]).to eq(1)
        expect(metrics[:total_characters]).to eq(100)
        expect(metrics[:translations_by_language]["en->fr"]).to eq(1)
      end

      it "does not update metrics when disabled" do
        config.enable_metrics = false
        config.trigger_translation_start("en", "fr", 100)

        expect(config.metrics).to eq({})
      end
    end

    describe "#trigger_translation_complete" do
      it "calls the callback when set" do
        callback_args = []
        config.on_translation_complete = lambda { |from, to, orig_len, trans_len, duration|
          callback_args = [from, to, orig_len, trans_len, duration]
        }

        config.trigger_translation_complete("en", "fr", 100, 120, 2.5)
        expect(callback_args).to eq(["en", "fr", 100, 120, 2.5])
      end

      it "updates duration metrics" do
        config.trigger_translation_complete("en", "fr", 100, 120, 2.5)

        expect(config.metrics[:total_duration]).to eq(2.5)
      end
    end

    describe "#trigger_translation_error" do
      it "calls the callback when set" do
        callback_called = false
        config.on_translation_error = ->(_from, _to, _error, _attempt, _timestamp) { callback_called = true }

        error = StandardError.new("test error")
        config.trigger_translation_error("en", "fr", error, 1)
        expect(callback_called).to be true
      end

      it "updates error count" do
        error = StandardError.new("test error")
        config.trigger_translation_error("en", "fr", error, 1)

        expect(config.metrics[:errors_count]).to eq(1)
      end
    end

    describe "#trigger_rate_limit" do
      it "calls the callback when set" do
        callback_called = false
        config.on_rate_limit = ->(_from, _to, _wait_time, _attempt, _timestamp) { callback_called = true }

        config.trigger_rate_limit("en", "fr", 5, 1)
        expect(callback_called).to be true
      end

      it "updates rate limit count" do
        config.trigger_rate_limit("en", "fr", 5, 1)

        expect(config.metrics[:rate_limits_hit]).to eq(1)
      end
    end

    describe "#trigger_batch_complete" do
      it "calls the callback when set" do
        callback_args = []
        config.on_batch_complete = lambda { |batch_size, duration, success, errors|
          callback_args = [batch_size, duration, success, errors]
        }

        config.trigger_batch_complete(10, 25.0, 8, 2)
        expect(callback_args).to eq([10, 25.0, 8, 2])
      end
    end
  end

  describe "#metrics" do
    before { config.enable_metrics = true }

    it "returns empty hash when metrics disabled" do
      config.enable_metrics = false
      expect(config.metrics).to eq({})
    end

    it "calculates average translation time" do
      config.trigger_translation_start("en", "fr", 100)
      config.trigger_translation_complete("en", "fr", 100, 120, 2.0)
      config.trigger_translation_start("fr", "en", 120)
      config.trigger_translation_complete("fr", "en", 120, 100, 3.0)

      metrics = config.metrics
      expect(metrics[:average_translation_time]).to eq(2.5)
    end

    it "calculates average characters per translation" do
      config.trigger_translation_start("en", "fr", 100)
      config.trigger_translation_start("fr", "en", 200)

      metrics = config.metrics
      expect(metrics[:average_characters_per_translation]).to eq(150)
    end

    it "calculates error rate" do
      config.trigger_translation_start("en", "fr", 100)
      config.trigger_translation_error("en", "fr", StandardError.new, 1)
      config.trigger_translation_start("fr", "en", 100)

      metrics = config.metrics
      expect(metrics[:error_rate]).to eq(50.0) # 1 erreur sur 2 traductions
    end

    it "handles zero translations gracefully" do
      metrics = config.metrics
      expect(metrics[:average_translation_time]).to eq(0)
      expect(metrics[:average_characters_per_translation]).to eq(0)
      expect(metrics[:error_rate]).to eq(0)
    end
  end

  describe "#reset_metrics!" do
    before do
      config.enable_metrics = true
      config.trigger_translation_start("en", "fr", 100)
      config.trigger_translation_error("en", "fr", StandardError.new, 1)
    end

    it "resets all metrics to initial values" do
      expect(config.metrics[:total_translations]).to eq(1)
      expect(config.metrics[:errors_count]).to eq(1)

      config.reset_metrics!

      metrics = config.metrics
      expect(metrics[:total_translations]).to eq(0)
      expect(metrics[:errors_count]).to eq(0)
      expect(metrics[:total_characters]).to eq(0)
      expect(metrics[:translations_by_language]).to eq({})
    end
  end

  describe "#setup_rails_logging" do
    context "when Rails is defined" do
      before do
        # Mock Rails and logger
        stub_const("Rails", double("Rails"))
        allow(Rails).to receive(:logger).and_return(double("Logger", info: nil, error: nil, warn: nil))
      end

      it "sets up Rails-compatible callbacks" do
        config.setup_rails_logging

        expect(config.on_translation_start).not_to be_nil
        expect(config.on_translation_complete).not_to be_nil
        expect(config.on_translation_error).not_to be_nil
        expect(config.on_rate_limit).not_to be_nil
      end

      it "logs translation start" do
        config.setup_rails_logging

        expect(Rails.logger).to receive(:info).with(/Starting translation en->fr/)
        config.trigger_translation_start("en", "fr", 100)
      end

      it "logs translation complete" do
        config.setup_rails_logging

        expect(Rails.logger).to receive(:info).with(/Completed en->fr in/)
        config.trigger_translation_complete("en", "fr", 100, 120, 2.5)
      end

      it "logs translation error" do
        config.setup_rails_logging

        error = StandardError.new("test error")
        expect(Rails.logger).to receive(:error).with(/Error en->fr/)
        config.trigger_translation_error("en", "fr", error, 1)
      end

      it "logs rate limit" do
        config.setup_rails_logging

        expect(Rails.logger).to receive(:warn).with(/Rate limit en->fr/)
        config.trigger_rate_limit("en", "fr", 5, 1)
      end
    end

    context "when Rails is not defined" do
      it "does not raise error" do
        expect { config.setup_rails_logging }.not_to raise_error
      end
    end
  end
end

RSpec.describe MistralTranslator do
  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(MistralTranslator::Configuration)
    end

    it "returns the same instance on multiple calls" do
      config1 = described_class.configuration
      config2 = described_class.configuration
      expect(config1).to be(config2)
    end
  end

  describe ".configure" do
    it "yields the configuration instance" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class.configuration)
    end

    it "allows setting configuration values" do
      described_class.configure do |config|
        config.api_key = "configured_key"
        config.model = "mistral-large"
        config.enable_metrics = true
      end

      expect(described_class.configuration.api_key).to eq("configured_key")
      expect(described_class.configuration.model).to eq("mistral-large")
      expect(described_class.configuration.enable_metrics).to be true
    end
  end

  describe ".reset_configuration!" do
    before do
      described_class.configure do |config|
        config.api_key = "old_key"
        config.model = "mistral-large"
        config.enable_metrics = true
      end
    end

    it "resets configuration to defaults" do
      described_class.reset_configuration!

      config = described_class.configuration
      expect(config.api_key).to be_nil
      expect(config.model).to eq("mistral-small")
      expect(config.api_url).to eq("https://api.mistral.ai")
      expect(config.enable_metrics).to be false
    end

    it "creates a new configuration instance" do
      old_config = described_class.configuration
      described_class.reset_configuration!
      new_config = described_class.configuration

      expect(new_config).not_to be(old_config)
    end
  end

  # Nouveaux tests pour les métriques
  describe ".metrics" do
    it "delegates to configuration.metrics" do
      expect(described_class.configuration).to receive(:metrics)
      described_class.metrics
    end
  end

  describe ".reset_metrics!" do
    it "delegates to configuration.reset_metrics!" do
      expect(described_class.configuration).to receive(:reset_metrics!)
      described_class.reset_metrics!
    end
  end
end

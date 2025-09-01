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
  end
end

RSpec.describe MistralTranslator do
  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(MistralTranslator.configuration).to be_a(MistralTranslator::Configuration)
    end

    it "returns the same instance on multiple calls" do
      config1 = MistralTranslator.configuration
      config2 = MistralTranslator.configuration
      expect(config1).to be(config2)
    end
  end

  describe ".configure" do
    it "yields the configuration instance" do
      expect { |b| MistralTranslator.configure(&b) }.to yield_with_args(MistralTranslator.configuration)
    end

    it "allows setting configuration values" do
      MistralTranslator.configure do |config|
        config.api_key = "configured_key"
        config.model = "mistral-large"
      end

      expect(MistralTranslator.configuration.api_key).to eq("configured_key")
      expect(MistralTranslator.configuration.model).to eq("mistral-large")
    end
  end

  describe ".reset_configuration!" do
    before do
      MistralTranslator.configure do |config|
        config.api_key = "old_key"
        config.model = "mistral-large"
      end
    end

    it "resets configuration to defaults" do
      MistralTranslator.reset_configuration!

      config = MistralTranslator.configuration
      expect(config.api_key).to be_nil
      expect(config.model).to eq("mistral-small")
      expect(config.api_url).to eq("https://api.mistral.ai")
    end

    it "creates a new configuration instance" do
      old_config = MistralTranslator.configuration
      MistralTranslator.reset_configuration!
      new_config = MistralTranslator.configuration

      expect(new_config).not_to be(old_config)
    end
  end
end

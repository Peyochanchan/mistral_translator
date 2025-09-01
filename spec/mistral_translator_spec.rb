# frozen_string_literal: true

RSpec.describe MistralTranslator do
  before do
    # Setup valid configuration for tests
    described_class.configure do |config|
      config.api_key = "test_api_key"
    end
  end

  describe ".version" do
    it "returns the current version" do
      expect(described_class.version).to eq(MistralTranslator::VERSION)
    end
  end

  describe ".translate" do
    it "delegates to Translator instance" do
      mock_translator = instance_double(MistralTranslator::Translator)
      allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)
      expect(mock_translator).to receive(:translate).with("Hello", from: "en", to: "fr").and_return("Bonjour")

      result = described_class.translate("Hello", from: "en", to: "fr")
      expect(result).to eq("Bonjour")
    end
  end

  describe ".translate_to_multiple" do
    it "delegates to Translator instance" do
      mock_translator = instance_double(MistralTranslator::Translator)
      allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)
      expected_result = { "fr" => "Bonjour", "es" => "Hola" }

      expect(mock_translator).to receive(:translate_to_multiple)
        .with("Hello", from: "en", to: %w[fr es])
        .and_return(expected_result)

      result = described_class.translate_to_multiple("Hello", from: "en", to: %w[fr es])
      expect(result).to eq(expected_result)
    end
  end

  describe ".translate_batch" do
    it "delegates to Translator instance" do
      mock_translator = instance_double(MistralTranslator::Translator)
      allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)
      texts = %w[Hello Goodbye]
      expected_result = { 0 => "Bonjour", 1 => "Au revoir" }

      expect(mock_translator).to receive(:translate_batch)
        .with(texts, from: "en", to: "fr")
        .and_return(expected_result)

      result = described_class.translate_batch(texts, from: "en", to: "fr")
      expect(result).to eq(expected_result)
    end
  end

  describe ".translate_auto" do
    it "delegates to Translator instance" do
      mock_translator = instance_double(MistralTranslator::Translator)
      allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)

      expect(mock_translator).to receive(:translate_auto)
        .with("Bonjour", to: "en")
        .and_return("Hello")

      result = described_class.translate_auto("Bonjour", to: "en")
      expect(result).to eq("Hello")
    end
  end

  describe ".summarize" do
    it "delegates to Summarizer instance" do
      mock_summarizer = instance_double(MistralTranslator::Summarizer)
      allow(MistralTranslator::Summarizer).to receive(:new).and_return(mock_summarizer)

      expect(mock_summarizer).to receive(:summarize)
        .with("Long text", language: "fr", max_words: 100)
        .and_return("Summary")

      result = described_class.summarize("Long text", language: "fr", max_words: 100)
      expect(result).to eq("Summary")
    end
  end

  describe ".summarize_and_translate" do
    it "delegates to Summarizer instance" do
      mock_summarizer = instance_double(MistralTranslator::Summarizer)
      allow(MistralTranslator::Summarizer).to receive(:new).and_return(mock_summarizer)

      expect(mock_summarizer).to receive(:summarize_and_translate)
        .with("Long text", from: "fr", to: "en", max_words: 150)
        .and_return("Translated summary")

      result = described_class.summarize_and_translate("Long text", from: "fr", to: "en", max_words: 150)
      expect(result).to eq("Translated summary")
    end
  end

  describe ".summarize_to_multiple" do
    it "delegates to Summarizer instance" do
      mock_summarizer = instance_double(MistralTranslator::Summarizer)
      allow(MistralTranslator::Summarizer).to receive(:new).and_return(mock_summarizer)
      expected_result = { "fr" => "Résumé", "en" => "Summary" }

      expect(mock_summarizer).to receive(:summarize_to_multiple)
        .with("Long text", languages: %w[fr en], max_words: 200)
        .and_return(expected_result)

      result = described_class.summarize_to_multiple("Long text", languages: %w[fr en], max_words: 200)
      expect(result).to eq(expected_result)
    end
  end

  describe ".summarize_tiered" do
    it "delegates to Summarizer instance" do
      mock_summarizer = instance_double(MistralTranslator::Summarizer)
      allow(MistralTranslator::Summarizer).to receive(:new).and_return(mock_summarizer)
      expected_result = { short: "Short", medium: "Medium", long: "Long" }

      expect(mock_summarizer).to receive(:summarize_tiered)
        .with("Long text", language: "en", short: 30, medium: 100, long: 250)
        .and_return(expected_result)

      result = described_class.summarize_tiered("Long text", language: "en", short: 30, medium: 100, long: 250)
      expect(result).to eq(expected_result)
    end
  end

  describe "utility methods" do
    describe ".supported_languages" do
      it "returns formatted list of supported languages" do
        result = described_class.supported_languages
        expect(result).to be_a(String)
        expect(result).to include("fr (français)")
      end
    end

    describe ".supported_locales" do
      it "returns array of supported locales" do
        result = described_class.supported_locales
        expect(result).to be_an(Array)
        expect(result).to include("fr", "en")
      end
    end

    describe ".locale_supported?" do
      it "checks if locale is supported" do
        expect(described_class.locale_supported?("fr")).to be true
        expect(described_class.locale_supported?("xx")).to be false
      end
    end
  end

  describe ".health_check" do
    let(:mock_client) { instance_double(MistralTranslator::Client) }

    before do
      allow(MistralTranslator::Client).to receive(:new).and_return(mock_client)
    end

    it "returns ok status for successful API call" do
      allow(mock_client).to receive(:complete).and_return("test response")

      result = described_class.health_check
      expect(result).to eq({ status: :ok, message: "API connection successful" })
    end

    it "returns error status for authentication failure" do
      allow(mock_client).to receive(:complete)
        .and_raise(MistralTranslator::AuthenticationError, "Invalid key")

      result = described_class.health_check
      expect(result).to eq({ status: :error, message: "Authentication failed - check your API key" })
    end

    it "returns error status for API errors" do
      allow(mock_client).to receive(:complete)
        .and_raise(MistralTranslator::ApiError, "Server error")

      result = described_class.health_check
      expect(result).to eq({ status: :error, message: "API error: Server error" })
    end

    it "returns error status for unexpected errors" do
      allow(mock_client).to receive(:complete).and_raise(StandardError, "Unexpected")

      result = described_class.health_check
      expect(result).to eq({ status: :error, message: "Unexpected error: Unexpected" })
    end
  end

  describe "singleton behavior" do
    it "reuses translator instance" do
      translator1 = described_class.send(:translator)
      translator2 = described_class.send(:translator)
      expect(translator1).to be(translator2)
    end

    it "reuses summarizer instance" do
      summarizer1 = described_class.send(:summarizer)
      summarizer2 = described_class.send(:summarizer)
      expect(summarizer1).to be(summarizer2)
    end

    it "reuses client instance" do
      client1 = described_class.send(:client)
      client2 = described_class.send(:client)
      expect(client1).to be(client2)
    end

    it "resets instances when configuration is reset" do
      described_class.send(:translator)
      described_class.reset_configuration!

      # Les instances doivent être recréées
      expect(described_class.instance_variable_get(:@translator)).to be_nil
      expect(described_class.instance_variable_get(:@summarizer)).to be_nil
      expect(described_class.instance_variable_get(:@client)).to be_nil
    end
  end

  describe "version info" do
    describe ".version_info" do
      it "returns complete version information" do
        info = described_class.version_info

        expect(info).to include(
          gem_version: MistralTranslator::VERSION,
          api_version: "v1",
          supported_model: "mistral-small"
        )
        expect(info).to have_key(:ruby_version)
        expect(info).to have_key(:platform)
      end
    end
  end
end

# Tests pour les extensions String (optionnelles)
RSpec.describe "String extensions" do
  before do
    ENV["MISTRAL_TRANSLATOR_EXTEND_STRING"] = "true"
    load "mistral_translator.rb" # Recharger pour activer les extensions

    MistralTranslator.configure do |config|
      config.api_key = "test_api_key"
    end
  end

  after do
    ENV.delete("MISTRAL_TRANSLATOR_EXTEND_STRING")
  end

  describe "#mistral_translate" do
    it "calls MistralTranslator.translate" do
      expect(MistralTranslator).to receive(:translate)
        .with("Hello", from: "en", to: "fr")
        .and_return("Bonjour")

      result = "Hello".mistral_translate(from: "en", to: "fr")
      expect(result).to eq("Bonjour")
    end
  end

  describe "#mistral_summarize" do
    it "calls MistralTranslator.summarize" do
      expect(MistralTranslator).to receive(:summarize)
        .with("Long text", language: "fr", max_words: 100)
        .and_return("Summary")

      result = "Long text".mistral_summarize(language: "fr", max_words: 100)
      expect(result).to eq("Summary")
    end
  end
end

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

  # Nouveau test pour version_info
  describe ".version_info" do
    it "returns complete version information" do
      info = described_class.version_info

      expect(info).to include(
        gem_version: MistralTranslator::VERSION,
        api_version: MistralTranslator::API_VERSION,
        supported_model: MistralTranslator::SUPPORTED_MODEL
      )
      expect(info).to have_key(:ruby_version)
      expect(info).to have_key(:platform)
    end
  end

  describe ".translate" do
    it "delegates to Translator instance with additional options" do
      mock_translator = instance_double(MistralTranslator::Translator)
      allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)

      context = "technical"
      glossary = { "API" => "API" }

      expect(mock_translator).to receive(:translate)
        .with("Hello", from: "en", to: "fr", context: context, glossary: glossary)
        .and_return("Bonjour")

      result = described_class.translate("Hello", from: "en", to: "fr", context: context, glossary: glossary)
      expect(result).to eq("Bonjour")
    end

    it "works without additional options" do
      mock_translator = instance_double(MistralTranslator::Translator)
      allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)
      expect(mock_translator).to receive(:translate).with("Hello", from: "en", to: "fr").and_return("Bonjour")

      result = described_class.translate("Hello", from: "en", to: "fr")
      expect(result).to eq("Bonjour")
    end
  end

  describe ".translate_to_multiple" do
    it "delegates to Translator instance with options" do
      mock_translator = instance_double(MistralTranslator::Translator)
      allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)
      expected_result = { "fr" => "Bonjour", "es" => "Hola" }

      expect(mock_translator).to receive(:translate_to_multiple)
        .with("Hello", from: "en", to: %w[fr es], use_batch: true)
        .and_return(expected_result)

      result = described_class.translate_to_multiple("Hello", from: "en", to: %w[fr es], use_batch: true)
      expect(result).to eq(expected_result)
    end
  end

  describe ".translate_batch" do
    it "delegates to Translator instance with context and glossary" do
      mock_translator = instance_double(MistralTranslator::Translator)
      allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)
      texts = %w[Hello Goodbye]
      expected_result = { 0 => "Bonjour", 1 => "Au revoir" }

      context = "greeting"
      glossary = { "Hello" => "Bonjour" }

      expect(mock_translator).to receive(:translate_batch)
        .with(texts, from: "en", to: "fr", context: context, glossary: glossary)
        .and_return(expected_result)

      result = described_class.translate_batch(texts, from: "en", to: "fr", context: context, glossary: glossary)
      expect(result).to eq(expected_result)
    end
  end

  describe ".translate_auto" do
    it "delegates to Translator instance with options" do
      mock_translator = instance_double(MistralTranslator::Translator)
      allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)

      context = "greeting"
      expect(mock_translator).to receive(:translate_auto)
        .with("Bonjour", to: "en", context: context)
        .and_return("Hello")

      result = described_class.translate_auto("Bonjour", to: "en", context: context)
      expect(result).to eq("Hello")
    end
  end

  describe ".summarize" do
    it "delegates to Summarizer instance with additional options" do
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
    it "delegates to Summarizer instance with options" do
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
    it "delegates to Summarizer instance with style option" do
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
    it "delegates to Summarizer instance with context option" do
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

  # Nouveaux tests pour les métriques
  describe ".metrics" do
    it "delegates to configuration.metrics" do
      expect(described_class.configuration).to receive(:metrics).and_return({ total_translations: 5 })

      result = described_class.metrics
      expect(result[:total_translations]).to eq(5)
    end
  end

  describe ".reset_metrics!" do
    it "delegates to configuration.reset_metrics!" do
      expect(described_class.configuration).to receive(:reset_metrics!)
      described_class.reset_metrics!
    end
  end

  describe ".health_check" do
    let(:mock_client) { instance_double(MistralTranslator::Client) }

    before do
      allow(MistralTranslator::Client).to receive(:new).and_return(mock_client)
    end

    it "returns ok status for successful API call" do
      allow(mock_client).to receive(:complete).with("Hello", max_tokens: 10, context: {}).and_return("test response")

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

    # Nouveau test pour vérifier que le contexte est passé
    it "passes empty context to client.complete" do
      expect(mock_client).to receive(:complete).with("Hello", max_tokens: 10, context: {})
      described_class.health_check
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

  describe "Convenience module" do
    let(:test_class) do
      Class.new do
        include MistralTranslator::Convenience
      end
    end

    describe ".mistral_translate" do
      it "calls MistralTranslator.translate with options" do
        context = "technical"
        expect(described_class).to receive(:translate)
          .with("Hello", from: "en", to: "fr", context: context)
          .and_return("Bonjour")

        result = test_class.mistral_translate("Hello", from: "en", to: "fr", context: context)
        expect(result).to eq("Bonjour")
      end
    end

    describe ".mistral_summarize" do
      it "calls MistralTranslator.summarize with options" do
        style = "formal"
        expect(described_class).to receive(:summarize)
          .with("Long text", language: "fr", max_words: 100, style: style)
          .and_return("Summary")

        result = test_class.mistral_summarize("Long text", language: "fr", max_words: 100, style: style)
        expect(result).to eq("Summary")
      end
    end
  end
end

# Tests pour les extensions String (optionnelles) avec nouvelles options
RSpec.describe "String extensions" do
  before do
    ENV["MISTRAL_TRANSLATOR_EXTEND_STRING"] = "true"
    load "lib/mistral_translator.rb" # Recharger pour activer les extensions

    MistralTranslator.configure do |config|
      config.api_key = "test_api_key"
    end
  end

  after do
    ENV.delete("MISTRAL_TRANSLATOR_EXTEND_STRING")
  end

  describe "#mistral_translate" do
    it "calls MistralTranslator.translate with additional options" do
      context = "greeting"
      glossary = { "Hello" => "Bonjour" }

      expect(MistralTranslator).to receive(:translate)
        .with("Hello", from: "en", to: "fr", context: context, glossary: glossary)
        .and_return("Bonjour")

      result = "Hello".mistral_translate(from: "en", to: "fr", context: context, glossary: glossary)
      expect(result).to eq("Bonjour")
    end

    it "works without additional options" do
      expect(MistralTranslator).to receive(:translate)
        .with("Hello", from: "en", to: "fr")
        .and_return("Bonjour")

      result = "Hello".mistral_translate(from: "en", to: "fr")
      expect(result).to eq("Bonjour")
    end
  end

  describe "#mistral_summarize" do
    it "calls MistralTranslator.summarize with style option" do
      style = "academic"
      context = "research"

      expect(MistralTranslator).to receive(:summarize)
        .with("Long text", language: "fr", max_words: 100, style: style, context: context)
        .and_return("Summary")

      result = "Long text".mistral_summarize(language: "fr", max_words: 100, style: style, context: context)
      expect(result).to eq("Summary")
    end

    it "works with default options" do
      expect(MistralTranslator).to receive(:summarize)
        .with("Long text", language: "fr", max_words: 250)
        .and_return("Summary")

      result = "Long text".mistral_summarize
      expect(result).to eq("Summary")
    end
  end
end

# Tests d'intégration pour vérifier que tous les modules fonctionnent ensemble
RSpec.describe "MistralTranslator Integration" do
  before do
    MistralTranslator.configure do |config|
      config.api_key = "test_api_key"
      config.enable_metrics = true
    end
  end

  describe "with callbacks and metrics" do
    let(:translation_calls) { [] }
    let(:error_calls) { [] }

    before do
      MistralTranslator.configure do |config|
        config.on_translation_start = lambda { |from, to, length, _timestamp|
          translation_calls << { event: :start, from: from, to: to, length: length }
        }
        config.on_translation_complete = lambda { |from, to, _orig_len, _trans_len, duration|
          translation_calls << { event: :complete, from: from, to: to, duration: duration }
        }
        config.on_translation_error = lambda { |from, to, error, attempt, _timestamp|
          error_calls << { from: from, to: to, error: error.class.name, attempt: attempt }
        }
      end
    end

    it "integrates callbacks with translation flow" do
      # Mock le client pour simuler les appels de callbacks comme ils se passent vraiment
      mock_client = instance_double(MistralTranslator::Client)
      allow(MistralTranslator::Client).to receive(:new).and_return(mock_client)

      response = { content: { target: "Bonjour" } }.to_json

      # Mock le client pour appeler les callbacks comme dans la vraie vie
      expect(mock_client).to receive(:complete) do |prompt, context:|
        # Simuler l'appel des callbacks comme dans Client#complete
        Time.now

        # Trigger callback pour le début de traduction
        MistralTranslator.configuration.trigger_translation_start(
          context[:from_locale],
          context[:to_locale],
          prompt&.length || 0
        )

        # Simuler la durée de traduction
        duration = 0.1

        # Trigger callback pour la fin de traduction
        MistralTranslator.configuration.trigger_translation_complete(
          context[:from_locale],
          context[:to_locale],
          prompt&.length || 0,
          response.length,
          duration
        )

        response
      end

      result = MistralTranslator.translate("Hello", from: "en", to: "fr")

      expect(result).to eq("Bonjour")
      expect(translation_calls.length).to eq(2)
      expect(translation_calls.first[:event]).to eq(:start)
      expect(translation_calls.last[:event]).to eq(:complete)
      expect(error_calls).to be_empty
    end

    it "tracks metrics during translation" do
      MistralTranslator.reset_metrics!
      # S'assurer que les métriques sont activées
      MistralTranslator.configure { |c| c.enable_metrics = true }

      mock_client = instance_double(MistralTranslator::Client)
      allow(MistralTranslator::Client).to receive(:new).and_return(mock_client)

      response = { content: { target: "Bonjour" } }.to_json

      # Mock le client pour appeler les callbacks de métriques
      expect(mock_client).to receive(:complete) do |prompt, context:|
        # Simuler l'appel des callbacks de métriques comme dans Client#complete
        MistralTranslator.configuration.trigger_translation_start(
          context[:from_locale],
          context[:to_locale],
          prompt&.length || 0
        )

        MistralTranslator.configuration.trigger_translation_complete(
          context[:from_locale],
          context[:to_locale],
          prompt&.length || 0,
          response.length,
          0.1
        )

        response
      end

      MistralTranslator.translate("Hello", from: "en", to: "fr")

      metrics = MistralTranslator.metrics
      expect(metrics[:total_translations]).to eq(1)
      expect(metrics[:total_characters]).to be > 0 # Le prompt complet, pas juste "Hello"
      expect(metrics[:translations_by_language]["en->fr"]).to eq(1)
    end
  end

  describe "Record Translation Integration" do
    let(:mock_record) do
      record = double("Topic")
      allow(record).to receive_messages(save!: true, name_en: "English Name", name_fr: "", name_es: "")
      allow(record).to receive(:name_fr=)
      allow(record).to receive(:name_es=)
      record
    end

    it "translates records using adapters" do
      # Mock MistralTranslator.translate pour éviter les appels API réels
      allow(MistralTranslator).to receive(:translate).and_return("Nom français", "Nombre español")

      # Créer un adaptateur I18n par défaut
      adapter = MistralTranslator::Adapters::I18nAttributesAdapter.new(mock_record)
      allow(adapter).to receive(:available_locales).and_return(%i[en fr es])

      service = MistralTranslator::Adapters::RecordTranslationService.new(
        mock_record,
        ["name"],
        adapter: adapter,
        source_locale: :en
      )

      result = service.translate_to_all_locales

      expect(result).to be true
      expect(mock_record).to have_received(:name_fr=).with("Nom français")
      expect(mock_record).to have_received(:name_es=).with("Nombre español")
    end
  end

  describe "Helpers Integration" do
    it "provides smart summarization" do
      allow(MistralTranslator).to receive(:summarize).and_return("Smart summary")

      html_content = "<div><p>This is a <strong>long</strong> HTML content that needs summarization.</p></div>"

      result = MistralTranslator::Helpers.smart_summarize(html_content, max_words: 50)

      expect(result[:summary]).to eq("Smart summary")
      expect(result[:original_length]).to be > 0
      expect(result[:compression_ratio]).to be_a(Float)
    end

    it "validates locales with suggestions" do
      result = MistralTranslator::Helpers.validate_locale_with_suggestions("fre")

      expect(result[:valid]).to be false
      expect(result[:suggestions]).to include("fr")
      expect(result[:supported_locales]).to be_an(Array)
    end

    it "estimates translation costs" do
      text = "Hello world! This is a test."

      result = MistralTranslator::Helpers.estimate_translation_cost(text, from: "en", to: "fr")

      expect(result[:character_count]).to eq(text.length)
      expect(result[:estimated_cost]).to be_a(Float)
      expect(result[:currency]).to eq("USD")
    end
  end

  describe "Error Handling Integration" do
    it "handles cascading errors gracefully" do
      # Simuler une erreur dans le client
      mock_client = instance_double(MistralTranslator::Client)
      allow(MistralTranslator::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:complete).and_raise(MistralTranslator::ApiError, "API down")

      expect do
        MistralTranslator.translate("Hello", from: "en", to: "fr")
      end.to raise_error(MistralTranslator::ApiError, "API down")
    end

    it "handles invalid configurations" do
      MistralTranslator.reset_configuration!

      expect do
        MistralTranslator.translate("Hello", from: "en", to: "fr")
      end.to raise_error(MistralTranslator::ConfigurationError, /API key is required/)
    end
  end
end

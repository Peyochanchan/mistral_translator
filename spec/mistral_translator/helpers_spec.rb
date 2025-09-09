# frozen_string_literal: true

RSpec.describe MistralTranslator::Helpers do
  before do
    MistralTranslator.configure { |c| c.api_key = "test_api_key" }
  end

  describe ".translate_rich_text" do
    it "calls translate with preserve_html option" do
      expect(MistralTranslator).to receive(:translate)
        .with("<p>Hello</p>", from: "en", to: "fr", context: nil, glossary: nil, preserve_html: true)
        .and_return("<p>Bonjour</p>")

      result = described_class.translate_rich_text("<p>Hello</p>", from: "en", to: "fr")
      expect(result).to eq("<p>Bonjour</p>")
    end

    it "passes context and glossary" do
      context = "technical documentation"
      glossary = { "API" => "API" }

      expect(MistralTranslator).to receive(:translate)
        .with("<p>API documentation</p>", from: "en", to: "fr",
                                          context: context, glossary: glossary, preserve_html: true)

      described_class.translate_rich_text(
        "<p>API documentation</p>",
        from: "en",
        to: "fr",
        context: context,
        glossary: glossary
      )
    end
  end

  describe ".translate_with_quality_check" do
    let(:mock_translator) { instance_double(MistralTranslator::Translator) }
    let(:mock_client) { instance_double(MistralTranslator::Client) }
    let(:quality_response) do
      {
        content: {
          target: "Bonjour"
        },
        metadata: {
          quality_check: {
            terminology_consistency: "vérifié",
            style_preservation: "vérifié",
            completeness: "vérifié"
          }
        }
      }.to_json
    end

    before do
      allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)
      allow(MistralTranslator::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:complete).and_return(quality_response)
      allow(MistralTranslator::PromptBuilder)
        .to receive(:translation_with_validation_prompt).and_return("validation prompt")
    end

    it "returns translation with quality check results" do
      result = described_class.translate_with_quality_check("Hello", from: "en", to: "fr")

      expect(result).to eq({
                             translation: "Bonjour",
                             quality_check: {
                               "terminology_consistency" => "vérifié",
                               "style_preservation" => "vérifié",
                               "completeness" => "vérifié"
                             },
                             metadata: {
                               "quality_check" => {
                                 "terminology_consistency" => "vérifié",
                                 "style_preservation" => "vérifié",
                                 "completeness" => "vérifié"
                               }
                             }
                           })
    end

    it "uses validation prompt" do
      expect(MistralTranslator::PromptBuilder).to receive(:translation_with_validation_prompt)
        .with("Hello", "en", "fr", context: nil, glossary: nil)

      described_class.translate_with_quality_check("Hello", from: "en", to: "fr")
    end
  end

  describe ".translate_batch_with_fallback" do
    let(:texts) { ["Hello", "Goodbye", "Thank you"] }
    let(:mock_translator) { instance_double(MistralTranslator::Translator) }

    before do
      allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)
    end

    context "when batch succeeds completely" do
      it "returns batch results" do
        batch_results = { 0 => "Bonjour", 1 => "Au revoir", 2 => "Merci" }
        expect(mock_translator).to receive(:translate_batch).and_return(batch_results)

        result = described_class.translate_batch_with_fallback(texts, from: "en", to: "fr")
        expect(result).to eq(batch_results)
      end
    end

    context "when batch has missing results" do
      it "retries missing items individually" do
        batch_results = { 0 => "Bonjour", 1 => nil, 2 => "Merci" }
        expect(mock_translator).to receive(:translate_batch).and_return(batch_results)
        expect(mock_translator).to receive(:translate).with("Goodbye", from: "en", to: "fr", context: nil,
                                                                       glossary: nil).and_return("Au revoir")

        result = described_class.translate_batch_with_fallback(texts, from: "en", to: "fr")
        expect(result[1]).to eq("Au revoir")
      end

      it "handles individual failures gracefully" do
        batch_results = { 0 => "Bonjour", 1 => nil, 2 => "Merci" }
        expect(mock_translator).to receive(:translate_batch).and_return(batch_results)
        expect(mock_translator).to receive(:translate).and_raise(StandardError, "Translation failed")

        result = described_class.translate_batch_with_fallback(texts, from: "en", to: "fr")
        expect(result[1]).to eq({ error: "Translation failed" })
      end
    end

    context "when batch fails completely" do
      it "falls back to individual translations" do
        expect(mock_translator).to receive(:translate_batch).and_raise(StandardError, "Batch failed")
        expect(described_class).to receive(:translate_individually_with_errors).and_return({ 0 => "Bonjour" })

        result = described_class.translate_batch_with_fallback(texts, from: "en", to: "fr")
        expect(result).to eq({ 0 => "Bonjour" })
      end

      it "raises error when fallback strategy is not individual" do
        expect(mock_translator).to receive(:translate_batch).and_raise(StandardError, "Batch failed")

        expect do
          described_class.translate_batch_with_fallback(texts, from: "en", to: "fr", fallback_strategy: :none)
        end.to raise_error(StandardError, "Batch failed")
      end
    end
  end

  describe ".translate_with_progress" do
    it "translates with progress callback" do
      items = { article1: "Hello", article2: "Goodbye" }
      progress_calls = []

      expect(MistralTranslator).to receive(:translate).with("Hello", from: "en", to: "fr", context: nil,
                                                                     glossary: nil).and_return("Bonjour")
      expect(MistralTranslator).to receive(:translate).with("Goodbye", from: "en", to: "fr", context: nil,
                                                                       glossary: nil).and_return("Au revoir")

      result = described_class.translate_with_progress(items, from: "en",
                                                              to: "fr") do |current, total, key, translation_result|
        progress_calls << { current: current, total: total, key: key, result: translation_result }
      end

      expect(result[:article1][:success]).to be true
      expect(result[:article1][:translation]).to eq("Bonjour")
      expect(result[:article2][:success]).to be true
      expect(result[:article2][:translation]).to eq("Au revoir")

      expect(progress_calls.length).to eq(2)
      expect(progress_calls.first[:current]).to eq(1)
      expect(progress_calls.first[:total]).to eq(2)
      expect(progress_calls.first[:key]).to eq(:article1)
    end

    it "handles errors gracefully" do
      items = { article1: "Hello" }

      expect(MistralTranslator).to receive(:translate).and_raise(StandardError, "API Error")

      result = described_class.translate_with_progress(items, from: "en", to: "fr")

      expect(result[:article1][:success]).to be false
      expect(result[:article1][:error]).to eq("API Error")
    end
  end

  describe ".smart_summarize" do
    before do
      allow(MistralTranslator).to receive(:summarize).and_return("Smart summary")
    end

    it "detects HTML content" do
      html_text = "<p>This is <strong>HTML</strong> content</p>"

      result = described_class.smart_summarize(html_text, max_words: 100)

      expect(result[:summary]).to eq("Smart summary")
      expect(result[:original_length]).to be > 0
      expect(result[:compression_ratio]).to be_a(Float)
    end

    it "calculates optimal summary length for short text" do
      short_text = "Short text content"
      expect(described_class).to receive(:calculate_optimal_summary_length).and_return(50)

      expect(MistralTranslator).to receive(:summarize).with(short_text, language: "fr", max_words: 50, style: nil,
                                                                        context: nil)

      described_class.smart_summarize(short_text, max_words: 100, target_language: "fr")
    end

    it "strips HTML for analysis" do
      html_text = "<div><p>Content with <strong>tags</strong></p></div>"

      result = described_class.smart_summarize(html_text)

      # Le texte analysé ne devrait pas contenir de balises HTML
      expect(result[:original_length]).to eq(3) # "Content with tags" = 3 mots
    end

    it "includes compression ratio in results" do
      allow(described_class).to receive(:calculate_optimal_summary_length).and_return(25)

      result = described_class.smart_summarize("Word " * 100) # 100 mots

      expect(result[:compression_ratio]).to eq(25.0) # 25/100 * 100
    end
  end

  describe ".translate_multi_style" do
    it "translates with multiple styles" do
      styles = %i[formal casual]

      expect(MistralTranslator).to receive(:translate)
        .with("Hello", from: "en", to: "fr", context: "Style: formal", glossary: nil)
        .and_return("Bonjour (formel)")

      expect(MistralTranslator).to receive(:translate)
        .with("Hello", from: "en", to: "fr", context: "Style: casual", glossary: nil)
        .and_return("Salut (casual)")

      result = described_class.translate_multi_style("Hello", from: "en", to: "fr", styles: styles)

      expect(result[:formal]).to eq("Bonjour (formel)")
      expect(result[:casual]).to eq("Salut (casual)")
    end

    it "combines context with style" do
      context = "Technical documentation"

      expect(MistralTranslator).to receive(:translate)
        .with("API", from: "en", to: "fr", context: "Technical documentation (Style: formal)", glossary: nil)

      described_class.translate_multi_style("API", from: "en", to: "fr", styles: [:formal], context: context)
    end

    it "handles translation errors" do
      expect(MistralTranslator).to receive(:translate).and_raise(StandardError, "Translation failed")

      result = described_class.translate_multi_style("Hello", from: "en", to: "fr", styles: [:formal])

      expect(result[:formal]).to eq({ error: "Translation failed" })
    end
  end

  describe ".validate_locale_with_suggestions" do
    it "returns valid result for supported locale" do
      result = described_class.validate_locale_with_suggestions("fr")

      expect(result[:valid]).to be true
      expect(result[:locale]).to eq("fr")
    end

    it "returns suggestions for invalid locale" do
      result = described_class.validate_locale_with_suggestions("fre")

      expect(result[:valid]).to be false
      expect(result[:error]).to include("Unsupported language")
      expect(result[:suggestions]).to include("fr")
      expect(result[:supported_locales]).to be_an(Array)
    end

    it "finds suggestions by prefix" do
      suggestions = described_class.send(:find_locale_suggestions, "fr")
      expect(suggestions).to include("fr")
    end

    it "finds suggestions by Levenshtein distance" do
      # "enn" devrait suggérer "en"
      suggestions = described_class.send(:find_locale_suggestions, "enn")
      expect(suggestions).to include("en")
    end

    it "limits suggestions to 3" do
      suggestions = described_class.send(:find_locale_suggestions, "x")
      expect(suggestions.length).to be <= 3
    end
  end

  describe ".estimate_translation_cost" do
    it "calculates cost based on character count" do
      text = "Hello world" # 11 caractères

      result = described_class.estimate_translation_cost(text, from: "en", to: "fr", rate_per_1k_chars: 0.02)

      expect(result[:character_count]).to eq(11)
      expect(result[:estimated_cost]).to eq(0.0002) # (11/1000) * 0.02 = 0.00022, arrondi à 0.0002
      expect(result[:currency]).to eq("USD")
      expect(result[:disclaimer]).to include("Estimation basique")
    end

    it "uses default rate" do
      result = described_class.estimate_translation_cost("x" * 1000, from: "en", to: "fr")

      expect(result[:estimated_cost]).to eq(0.02) # 1000 chars * 0.02/1000
      expect(result[:rate_used]).to eq(0.02)
    end
  end

  describe ".setup_rails_integration" do
    context "when Rails is defined" do
      before do
        stub_const("Rails", double("Rails"))
        allow(Rails).to receive(:cache).and_return(double("Cache", increment: nil, write: nil))
        allow(ENV).to receive(:fetch).with("MISTRAL_API_KEY", nil).and_return("test_key")
      end

      it "configures MistralTranslator with Rails settings" do
        described_class.setup_rails_integration(enable_metrics: true, setup_logging: true)

        config = MistralTranslator.configuration
        expect(config.api_key).to eq("test_key")
        expect(config.enable_metrics).to be true
        expect(config.on_translation_start).not_to be_nil
      end

      it "sets up Rails cache callbacks when metrics enabled" do
        described_class.setup_rails_integration(enable_metrics: true)

        config = MistralTranslator.configuration
        expect(config.on_translation_complete).not_to be_nil

        # Test du callback
        expect(Rails.cache).to receive(:increment).with("mistral_translator_translations_count", 1)
        expect(Rails.cache).to receive(:write).with("mistral_translator_last_translation", anything)

        config.on_translation_complete.call("en", "fr", 100, 120, 2.0)
      end

      it "uses provided API key over ENV" do
        described_class.setup_rails_integration(api_key: "custom_key")

        expect(MistralTranslator.configuration.api_key).to eq("custom_key")
      end
    end

    context "when Rails is not defined" do
      it "does not raise error" do
        expect { described_class.setup_rails_integration }.not_to raise_error
      end
    end
  end

  describe "private methods" do
    describe ".strip_html_for_analysis" do
      it "removes HTML tags" do
        html = "<div><p>Hello <strong>world</strong></p></div>"
        result = described_class.send(:strip_html_for_analysis, html)
        expect(result).to eq("Hello world")
      end

      it "normalizes whitespace" do
        html = "<div>  Multiple   \n\n  spaces  </div>"
        result = described_class.send(:strip_html_for_analysis, html)
        expect(result).to eq("Multiple spaces")
      end
    end

    describe ".calculate_optimal_summary_length" do
      it "returns half length for very short text" do
        result = described_class.send(:calculate_optimal_summary_length, "short text", 100)
        expect(result).to eq(1) # min(100, 2/2) = 1
      end

      it "returns third for short text" do
        text = ("word " * 200).strip # 200 mots
        result = described_class.send(:calculate_optimal_summary_length, text, 100)
        expect(result).to eq(66) # min(100, 200/3) = 66
      end

      it "returns max_words when calculation exceeds it" do
        text = ("word " * 50).strip # 50 mots
        result = described_class.send(:calculate_optimal_summary_length, text, 10)
        expect(result).to eq(10) # min(10, 50/3) = 10
      end
    end

    describe ".levenshtein_distance" do
      it "calculates correct distance" do
        expect(described_class.send(:levenshtein_distance, "kitten", "sitting")).to eq(3)
        expect(described_class.send(:levenshtein_distance, "fr", "en")).to eq(2)
        expect(described_class.send(:levenshtein_distance, "same", "same")).to eq(0)
      end

      it "handles empty strings" do
        expect(described_class.send(:levenshtein_distance, "", "hello")).to eq(5)
        expect(described_class.send(:levenshtein_distance, "hello", "")).to eq(5)
        expect(described_class.send(:levenshtein_distance, "", "")).to eq(0)
      end
    end

    describe ".translate_individually_with_errors" do
      let(:mock_translator) { instance_double(MistralTranslator::Translator) }

      before do
        allow(MistralTranslator::Translator).to receive(:new).and_return(mock_translator)
      end

      it "translates each text individually" do
        texts = %w[Hello Goodbye]

        expect(mock_translator).to receive(:translate).with("Hello", from: "en", to: "fr", context: nil,
                                                                     glossary: nil).and_return("Bonjour")
        expect(mock_translator).to receive(:translate).with("Goodbye", from: "en", to: "fr", context: nil,
                                                                       glossary: nil).and_return("Au revoir")

        result = described_class.send(:translate_individually_with_errors, texts, from: "en", to: "fr")

        expect(result).to eq({ 0 => "Bonjour", 1 => "Au revoir" })
      end

      it "handles individual errors" do
        texts = %w[Hello Error]

        expect(mock_translator).to receive(:translate).with("Hello", from: "en", to: "fr", context: nil,
                                                                     glossary: nil).and_return("Bonjour")
        expect(mock_translator)
          .to receive(:translate).with("Error", from: "en", to: "fr", context: nil, glossary: nil)
          .and_raise(StandardError, "Failed")

        result = described_class.send(:translate_individually_with_errors, texts, from: "en", to: "fr")

        expect(result[0]).to eq("Bonjour")
        expect(result[1]).to eq({ error: "Failed" })
      end
    end
  end

  describe "RecordHelpers module" do
    let(:mock_record) do
      record = Object.new
      record.extend(MistralTranslator::Helpers::RecordHelpers)
      mock_class = double("Class")
      allow(mock_class).to receive_messages(superclass: Object, name: "MockRecord")
      allow(record).to receive(:class).and_return(mock_class)
      record
    end

    describe "#translate_with_mistral" do
      it "creates adapter and service to translate" do
        mock_adapter = instance_double(MistralTranslator::Adapters::BaseAdapter)
        mock_service = instance_double(MistralTranslator::Adapters::RecordTranslationService)

        expect(MistralTranslator::Adapters::AdapterFactory)
          .to receive(:build_for).with(mock_record).and_return(mock_adapter)
        expect(MistralTranslator::Adapters::RecordTranslationService).to receive(:new)
          .with(mock_record, ["name"], adapter: mock_adapter, from: "fr", to: "en")
          .and_return(mock_service)
        expect(mock_service).to receive(:translate_to_all_locales).and_return(true)

        result = mock_record.translate_with_mistral(["name"], from: "fr", to: "en")
        expect(result).to be true
      end
    end

    describe "#estimate_translation_cost_for_fields" do
      it "calculates cost for multiple fields" do
        allow(mock_record).to receive_messages(name_fr: "Nom français", description_fr: "Description française")

        # "Nom français" (12) + "Description française" (21) = 33
        expect(described_class).to receive(:estimate_translation_cost)
          .with("x" * 33, from: "fr", to: "en", rate_per_1k_chars: 0.02)
          .and_return({ estimated_cost: 0.0007 })

        result = mock_record.estimate_translation_cost_for_fields(%w[name description], from: "fr", to: "en")
        expect(result[:estimated_cost]).to eq(0.0007)
      end

      it "handles ActionText fields" do
        rich_text = double("ActionText", to_plain_text: "Rich text content")
        allow(rich_text).to receive(:respond_to?).with(:to_plain_text).and_return(true)

        allow(mock_record).to receive(:description_fr).and_return(rich_text)

        expect(described_class).to receive(:estimate_translation_cost)
          .with("x" * 17, from: "fr", to: "en", rate_per_1k_chars: 0.02) # "Rich text content" = 17 chars

        mock_record.estimate_translation_cost_for_fields(["description"], from: "fr", to: "en")
      end

      it "handles missing fields gracefully" do
        allow(mock_record).to receive(:name_fr).and_raise(NoMethodError)

        expect(described_class).to receive(:estimate_translation_cost)
          .with("", from: "fr", to: "en", rate_per_1k_chars: 0.02)

        mock_record.estimate_translation_cost_for_fields(["name"], from: "fr", to: "en")
      end
    end
  end
end

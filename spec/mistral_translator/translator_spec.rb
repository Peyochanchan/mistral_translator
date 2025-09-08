# frozen_string_literal: true

RSpec.describe MistralTranslator::Translator do
  let(:mock_client) { instance_double(MistralTranslator::Client) }
  let(:translator) { described_class.new(client: mock_client) }

  before do
    MistralTranslator.configure { |c| c.api_key = "test_api_key" }
  end

  describe "#initialize" do
    it "uses provided client" do
      expect(translator.instance_variable_get(:@client)).to eq(mock_client)
    end

    it "creates default client when none provided" do
      default_translator = described_class.new
      expect(default_translator.instance_variable_get(:@client)).to be_a(MistralTranslator::Client)
    end
  end

  describe "#translate" do
    let(:raw_response) do
      {
        content: {
          source: "Hello",
          target: "Bonjour"
        }
      }.to_json
    end

    before do
      allow(mock_client).to receive(:complete).and_return(raw_response)
    end

    it "translates text successfully" do
      result = translator.translate("Hello", from: "en", to: "fr")
      expect(result).to eq("Bonjour")
    end

    it "validates and normalizes locales" do
      expect(MistralTranslator::LocaleHelper).to receive(:validate_locale!).with("en").and_return("en")
      expect(MistralTranslator::LocaleHelper).to receive(:validate_locale!).with("fr").and_return("fr")

      translator.translate("Hello", from: "en", to: "fr")
    end

    it "calls PromptBuilder with correct parameters" do
      expect(translator).to receive(:build_translation_prompt)
        .with("Hello", "en", "fr", context: nil, glossary: nil, preserve_html: false)
        .and_return("mocked prompt")

      translator.translate("Hello", from: "en", to: "fr")
    end

    # Nouveaux tests pour le contexte et glossaire
    it "passes context and glossary to prompt builder" do
      context = "technical documentation"
      glossary = { "API" => "API" }

      expect(translator).to receive(:build_translation_prompt)
        .with("Hello", "en", "fr", context: context, glossary: glossary, preserve_html: false)
        .and_return("enriched prompt")

      translator.translate("Hello", from: "en", to: "fr", context: context, glossary: glossary)
    end

    it "passes context to client" do
      expect(mock_client).to receive(:complete)
        .with(anything, context: {
                from_locale: "en",
                to_locale: "fr",
                attempt: 0
              })

      translator.translate("Hello", from: "en", to: "fr")
    end

    context "with validation errors" do
      it "raises ArgumentError for nil text" do
        expect { translator.translate(nil, from: "en", to: "fr") }.to raise_error(
          ArgumentError, "Text cannot be nil or empty"
        )
      end

      it "raises ArgumentError for empty text" do
        expect { translator.translate("", from: "en", to: "fr") }.to raise_error(
          ArgumentError, "Text cannot be nil or empty"
        )
      end

      it "raises ArgumentError for nil source language" do
        expect { translator.translate("Hello", from: nil, to: "fr") }.to raise_error(
          ArgumentError, "Source language cannot be nil"
        )
      end

      it "raises ArgumentError for same source and target" do
        expect { translator.translate("Hello", from: "en", to: "en") }.to raise_error(
          ArgumentError, "Source and target languages cannot be the same"
        )
      end
    end

    context "with API errors and retries" do
      it "retries on EmptyTranslationError" do
        allow(mock_client).to receive(:complete)
          .and_raise(MistralTranslator::EmptyTranslationError)
          .once
        allow(mock_client).to receive(:complete)
          .and_return(raw_response)
          .once

        expect { translator.translate("Hello", from: "en", to: "fr") }.not_to raise_error
      end

      it "raises error after max retries" do
        allow(mock_client).to receive(:complete)
          .and_raise(MistralTranslator::EmptyTranslationError)
          .exactly(4).times # 1 + 3 retries

        expect { translator.translate("Hello", from: "en", to: "fr") }.to raise_error(
          MistralTranslator::EmptyTranslationError
        )
      end

      it "retries indefinitely on RateLimitError" do
        call_count = 0
        allow(mock_client).to receive(:complete) do
          call_count += 1
          raise MistralTranslator::RateLimitError if call_count < 3

          raw_response
        end

        result = translator.translate("Hello", from: "en", to: "fr")
        expect(result).to eq("Bonjour")
        expect(call_count).to eq(3)
      end
    end
  end

  # Nouveau test pour translate_with_confidence
  describe "#translate_with_confidence" do
    let(:raw_response) do
      {
        content: {
          source: "Hello world",
          target: "Bonjour monde"
        }
      }.to_json
    end

    before do
      allow(mock_client).to receive(:complete).and_return(raw_response)
    end

    it "returns translation with confidence score" do
      result = translator.translate_with_confidence("Hello world", from: "en", to: "fr")

      expect(result).to have_key(:translation)
      expect(result).to have_key(:confidence)
      expect(result).to have_key(:metadata)

      expect(result[:translation]).to eq("Bonjour monde")
      expect(result[:confidence]).to be_a(Float)
      expect(result[:confidence]).to be_between(0, 1)

      expect(result[:metadata][:source_locale]).to eq("en")
      expect(result[:metadata][:target_locale]).to eq("fr")
      expect(result[:metadata][:original_length]).to eq(11)
      expect(result[:metadata][:translated_length]).to eq(13)
    end

    it "calculates confidence based on length ratio" do
      # Test avec une traduction de longueur suspecte
      suspicious_response = {
        content: {
          source: "Hello",
          target: "Bonjour le monde entier"
        }
      }.to_json

      allow(mock_client).to receive(:complete).and_return(suspicious_response)

      result = translator.translate_with_confidence("Hello", from: "en", to: "fr")
      expect(result[:confidence]).to be < 0.8 # Confiance réduite pour ratio suspect
    end

    it "returns zero confidence for empty translation" do
      empty_response = {
        content: {
          source: "Hello",
          target: ""
        }
      }.to_json

      allow(mock_client).to receive(:complete).and_return(empty_response)
      allow(MistralTranslator::ResponseParser).to receive(:parse_translation_response)
        .and_return({ translated: "" })

      result = translator.translate_with_confidence("Hello", from: "en", to: "fr")
      expect(result[:confidence]).to eq(0.0)
    end
  end

  describe "#translate_to_multiple" do
    let(:french_response) { '{"content": {"target": "Bonjour"}}' }
    let(:spanish_response) { '{"content": {"target": "Hola"}}' }

    before do
      allow(mock_client).to receive(:complete)
        .and_return(french_response, spanish_response)
    end

    it "translates to multiple languages" do
      result = translator.translate_to_multiple("Hello", from: "en", to: %w[fr es])

      expect(result).to eq({
                             "fr" => "Bonjour",
                             "es" => "Hola"
                           })
    end

    it "handles single target language" do
      result = translator.translate_to_multiple("Hello", from: "en", to: "fr")

      expect(result).to eq({ "fr" => "Bonjour" })
    end

    # Nouveau test pour le mode batch
    it "uses batch mode for many languages when enabled" do
      large_target_list = %w[fr es de it pt]

      expect(translator).to receive(:translate_to_multiple_batch)
        .with("Hello", "en", large_target_list, context: nil, glossary: nil)
        .and_return({ "fr" => "Bonjour" })

      result = translator.translate_to_multiple("Hello", from: "en", to: large_target_list, use_batch: true)
      expect(result).to eq({ "fr" => "Bonjour" })
    end

    it "uses sequential mode by default" do
      expect(translator).to receive(:translate_to_multiple_sequential)
        .with("Hello", "en", ["fr"], context: nil, glossary: nil)
        .and_return({ "fr" => "Bonjour" })

      translator.translate_to_multiple("Hello", from: "en", to: "fr")
    end

    it "adds delay between requests in sequential mode" do
      expect(translator).to receive(:sleep).with(2).once

      translator.translate_to_multiple("Hello", from: "en", to: %w[fr es])
    end

    it "validates target languages array" do
      expect { translator.translate_to_multiple("Hello", from: "en", to: []) }.to raise_error(
        ArgumentError, "Target languages cannot be empty"
      )
    end

    it "passes context and glossary to individual translations" do
      context = "technical"
      glossary = { "API" => "API" }

      expect(translator).to receive(:translate_with_retry)
        .with("Hello", "en", "fr", context: context, glossary: glossary)
        .and_return("Bonjour")

      translator.translate_to_multiple("Hello", from: "en", to: "fr", context: context, glossary: glossary)
    end
  end

  describe "#translate_batch" do
    let(:bulk_response) do
      {
        translations: [
          { index: 1, source: "Hello", target: "Bonjour" },
          { index: 2, source: "Goodbye", target: "Au revoir" }
        ]
      }.to_json
    end

    before do
      allow(mock_client).to receive(:translate_batch).and_return([
                                                                   { success: true, result: bulk_response,
                                                                     original_request: { index: 0 } },
                                                                   { success: true, result: bulk_response,
                                                                     original_request: { index: 1 } }
                                                                 ])
    end

    it "uses client's translate_batch method" do
      texts = %w[Hello Goodbye]

      expected_requests = [
        {
          prompt: anything,
          from: "en",
          to: "fr",
          index: 0,
          original_text: "Hello"
        },
        {
          prompt: anything,
          from: "en",
          to: "fr",
          index: 1,
          original_text: "Goodbye"
        }
      ]

      expect(mock_client).to receive(:translate_batch).with(expected_requests, batch_size: 10)
                                                      .and_return([
                                                                    { success: true,
                                                                      result: '{"content": {"target": "Bonjour"}}',
                                                                      original_request: { index: 0 } },
                                                                    { success: true,
                                                                      result: '{"content": {"target": "Au revoir"}}',
                                                                      original_request: { index: 1 } }
                                                                  ])

      result = translator.translate_batch(texts, from: "en", to: "fr")
      expect(result).to eq({ 0 => "Bonjour", 1 => "Au revoir" })
    end

    it "processes batch results correctly" do
      texts = %w[Hello Goodbye]
      batch_results = [
        {
          success: true,
          result: '{"content": {"target": "Bonjour"}}',
          original_request: { index: 0 }
        },
        {
          success: true,
          result: '{"content": {"target": "Au revoir"}}',
          original_request: { index: 1 }
        }
      ]

      allow(mock_client).to receive(:translate_batch).and_return(batch_results)

      result = translator.translate_batch(texts, from: "en", to: "fr")

      expect(result[0]).to eq("Bonjour")
      expect(result[1]).to eq("Au revoir")
    end

    it "handles batch errors gracefully" do
      texts = %w[Hello Error]
      batch_results = [
        {
          success: true,
          result: '{"content": {"target": "Bonjour"}}',
          original_request: { index: 0 }
        },
        {
          success: false,
          error: "Translation failed",
          original_request: { index: 1 }
        }
      ]

      allow(mock_client).to receive(:translate_batch).and_return(batch_results)

      result = translator.translate_batch(texts, from: "en", to: "fr")

      expect(result[0]).to eq("Bonjour")
      expect(result[1]).to be_nil
    end

    it "builds prompts with context and glossary" do
      context = "technical"
      glossary = { "API" => "API" }

      expect(translator).to receive(:build_translation_prompt)
        .with("Hello", "en", "fr", context: context, glossary: glossary)
        .and_return("enriched prompt")

      allow(mock_client).to receive(:translate_batch).and_return([
                                                                   { success: true,
                                                                     result: '{"content": {"target": "Bonjour"}}',
                                                                     original_request: { index: 0 } }
                                                                 ])

      result = translator.translate_batch(["Hello"], from: "en", to: "fr", context: context, glossary: glossary)
      expect(result).to eq({ 0 => "Bonjour" })
    end

    context "with validation errors" do
      it "raises ArgumentError for empty texts array" do
        expect { translator.translate_batch([], from: "en", to: "fr") }.to raise_error(
          ArgumentError, "Texts array cannot be nil or empty"
        )
      end

      it "raises ArgumentError for nil in texts array" do
        texts = ["Hello", nil, "Goodbye"]
        expect { translator.translate_batch(texts, from: "en", to: "fr") }.to raise_error(
          ArgumentError, "Text at index 1 cannot be nil or empty"
        )
      end
    end
  end

  describe "#translate_auto" do
    let(:detection_response) { '{"metadata": {"detected_language": "fr"}}' }
    let(:translation_response) { '{"content": {"target": "Hello"}}' }

    before do
      allow(mock_client).to receive(:complete)
        .and_return(detection_response, translation_response)
    end

    it "detects language and translates" do
      result = translator.translate_auto("Bonjour", to: "en")
      expect(result).to eq("Hello")
      expect(mock_client).to have_received(:complete).twice
    end

    it "passes context and glossary to translation" do
      context = "greeting"
      glossary = { "Bonjour" => "Hello" }

      expect(translator).to receive(:translate)
        .with("Bonjour", from: "fr", to: "en", context: context, glossary: glossary)
        .and_return("Hello")

      translator.translate_auto("Bonjour", to: "en", context: context, glossary: glossary)
    end

    it "uses english as fallback for detection errors" do
      allow(mock_client).to receive(:complete)
        .and_return("invalid json", translation_response)

      # Ne doit pas lever d'erreur, utilise 'en' par défaut
      expect { translator.translate_auto("Hello", to: "fr") }.not_to raise_error
    end
  end

  describe "private methods" do
    describe "#build_translation_prompt" do
      it "calls PromptBuilder.translation_prompt without enrichment" do
        expect(MistralTranslator::PromptBuilder).to receive(:translation_prompt)
          .with("Hello", "en", "fr", preserve_html: false)
          .and_return("basic prompt")

        result = translator.send(:build_translation_prompt, "Hello", "en", "fr")
        expect(result).to eq("basic prompt")
      end

      it "enriches prompt with context and glossary" do
        context = "technical documentation"
        glossary = { "API" => "API", "bug" => "bogue" }

        expect(MistralTranslator::PromptBuilder).to receive(:translation_prompt)
          .with("Hello", "en", "fr", preserve_html: false)
          .and_return("Tu es un traducteur professionnel.\n\nRÈGLES :\n- Traduis fidèlement")

        result = translator.send(:build_translation_prompt, "Hello", "en", "fr", context: context, glossary: glossary)

        expect(result).to include("CONTEXTE : technical documentation")
        expect(result).to include("GLOSSAIRE (à respecter strictement) : API → API, bug → bogue")
      end
    end

    describe "#enrich_prompt_with_context" do
      let(:base_prompt) { "Tu es un traducteur.\n\nRÈGLES :\n- Traduis fidèlement" }

      it "adds context section" do
        context = "medical documentation"
        result = translator.send(:enrich_prompt_with_context, base_prompt, context, nil)

        expect(result).to include("CONTEXTE : medical documentation")
        expect(result).to include("CONTEXTE : medical documentation\n\nRÈGLES :")
      end

      it "adds glossary section" do
        glossary = { "heart" => "cœur", "lung" => "poumon" }
        result = translator.send(:enrich_prompt_with_context, base_prompt, nil, glossary)

        expect(result).to include("GLOSSAIRE (à respecter strictement) : heart → cœur, lung → poumon")
      end

      it "adds both context and glossary" do
        context = "medical"
        glossary = { "heart" => "cœur" }
        result = translator.send(:enrich_prompt_with_context, base_prompt, context, glossary)

        expect(result).to include("CONTEXTE : medical")
        expect(result).to include("GLOSSAIRE (à respecter strictement) : heart → cœur")
      end

      it "returns original prompt when no enrichments" do
        result = translator.send(:enrich_prompt_with_context, base_prompt, nil, nil)
        expect(result).to eq(base_prompt)
      end

      it "handles empty glossary" do
        result = translator.send(:enrich_prompt_with_context, base_prompt, nil, {})
        expect(result).to eq(base_prompt)
      end
    end

    describe "#calculate_confidence_score" do
      it "returns high confidence for normal length ratio" do
        # fr->en ratio normal: autour de 0.8-1.2
        score = translator.send(:calculate_confidence_score, "Bonjour monde", "Hello world", "fr", "en")
        expect(score).to be >= 0.7
      end

      it "returns lower confidence for suspicious length ratio" do
        # Ratio très différent de la normale
        score = translator.send(:calculate_confidence_score, "Hello", "Bonjour le monde entier", "en", "fr")
        expect(score).to be < 0.8
      end

      it "returns zero for empty translation" do
        score = translator.send(:calculate_confidence_score, "Hello", "", "en", "fr")
        expect(score).to eq(0.0)
      end

      it "reduces confidence for very short texts" do
        # Textes très courts moins fiables
        score = translator.send(:calculate_confidence_score, "Hi", "Salut", "en", "fr")
        expect(score).to be <= 0.6
      end

      it "handles unknown language pairs with wide tolerance" do
        score = translator.send(:calculate_confidence_score, "Hello", "Hola", "en", "es")
        expect(score).to be_between(0.1, 0.95)
      end
    end

    describe "#translate_to_multiple_batch" do
      it "creates batch requests for multiple languages" do
        target_locales = %w[fr es]

        batch_results = [
          { success: true, result: '{"content": {"target": "Bonjour"}}', original_request: { to: "fr" } },
          { success: true, result: '{"content": {"target": "Hola"}}', original_request: { to: "es" } }
        ]

        expect(mock_client).to receive(:translate_batch).and_return(batch_results)

        result = translator.send(:translate_to_multiple_batch, "Hello", "en", target_locales)

        expect(result["fr"]).to eq("Bonjour")
        expect(result["es"]).to eq("Hola")
      end
    end

    describe "#translate_to_multiple_sequential" do
      it "calls translate_with_retry for each language" do
        target_locales = %w[fr es]

        expect(translator).to receive(:translate_with_retry)
          .with("Hello", "en", "fr", context: nil, glossary: nil)
          .and_return("Bonjour")
        expect(translator).to receive(:translate_with_retry)
          .with("Hello", "en", "es", context: nil, glossary: nil)
          .and_return("Hola")
        expect(translator).to receive(:sleep).with(2).once

        result = translator.send(:translate_to_multiple_sequential, "Hello", "en", target_locales)

        expect(result["fr"]).to eq("Bonjour")
        expect(result["es"]).to eq("Hola")
      end
    end

    describe "#process_batch_results" do
      it "maps batch results to original indices" do
        batch_results = [
          { success: true, result: '{"content": {"target": "Bonjour"}}', original_request: { index: 0 } },
          { success: false, error: "Failed", original_request: { index: 1 } }
        ]
        original_texts = %w[Hello Error]

        result = translator.send(:process_batch_results, batch_results, original_texts)

        expect(result[0]).to eq("Bonjour")
        expect(result[1]).to be_nil
      end
    end

    describe "#validate_inputs!" do
      it "validates all required inputs" do
        expect { translator.send(:validate_inputs!, nil, "en", "fr") }.to raise_error(ArgumentError)
        expect { translator.send(:validate_inputs!, "", "en", "fr") }.to raise_error(ArgumentError)
        expect { translator.send(:validate_inputs!, "Hello", nil, "fr") }.to raise_error(ArgumentError)
        expect { translator.send(:validate_inputs!, "Hello", "en", nil) }.to raise_error(ArgumentError)
        expect { translator.send(:validate_inputs!, "Hello", "en", "en") }.to raise_error(ArgumentError)
      end

      it "passes with valid inputs" do
        expect { translator.send(:validate_inputs!, "Hello", "en", "fr") }.not_to raise_error
      end
    end

    describe "#validate_batch_inputs!" do
      it "validates texts array" do
        expect { translator.send(:validate_batch_inputs!, nil, "en", "fr") }.to raise_error(ArgumentError)
        expect { translator.send(:validate_batch_inputs!, [], "en", "fr") }.to raise_error(ArgumentError)
      end

      it "validates individual texts" do
        texts = ["Hello", "", "World"]
        expect { translator.send(:validate_batch_inputs!, texts, "en", "fr") }.to raise_error(
          ArgumentError, "Text at index 1 cannot be nil or empty"
        )
      end

      it "passes with valid batch inputs" do
        texts = %w[Hello World]
        expect { translator.send(:validate_batch_inputs!, texts, "en", "fr") }.not_to raise_error
      end
    end

    describe "#parse_language_detection" do
      it "extracts detected language from response" do
        response = '{"metadata": {"detected_language": "fr", "confidence": 0.95}}'
        result = translator.send(:parse_language_detection, response)
        expect(result).to eq("fr")
      end

      it "returns 'en' for unsupported detected language" do
        response = '{"metadata": {"detected_language": "klingon"}}'
        allow(MistralTranslator::LocaleHelper).to receive(:locale_supported?).with("klingon").and_return(false)

        result = translator.send(:parse_language_detection, response)
        expect(result).to eq("en")
      end

      it "returns 'en' for invalid JSON" do
        response = "invalid json"
        result = translator.send(:parse_language_detection, response)
        expect(result).to eq("en")
      end

      it "returns 'en' when no JSON found" do
        response = "No JSON here"
        result = translator.send(:parse_language_detection, response)
        expect(result).to eq("en")
      end
    end
  end
end

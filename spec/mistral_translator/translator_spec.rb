# frozen_string_literal: true

RSpec.describe MistralTranslator::Translator do
  let(:mock_client) { instance_double(MistralTranslator::Client) }
  let(:translator) { described_class.new(client: mock_client) }

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
        "content": {
          "source": "Hello",
          "target": "Bonjour"
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
      expect(MistralTranslator::PromptBuilder).to receive(:translation_prompt)
        .with("Hello", "en", "fr")
        .and_return("mocked prompt")

      expect(mock_client).to receive(:complete).with("mocked prompt")

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

    it "adds delay between requests" do
      expect(translator).to receive(:sleep).with(2).once

      translator.translate_to_multiple("Hello", from: "en", to: %w[fr es])
    end

    it "validates target languages array" do
      expect { translator.translate_to_multiple("Hello", from: "en", to: []) }.to raise_error(
        ArgumentError, "Target languages cannot be empty"
      )
    end
  end

  describe "#translate_batch" do
    let(:bulk_response) do
      {
        "translations": [
          { "index": 1, "source": "Hello", "target": "Bonjour" },
          { "index": 2, "source": "Goodbye", "target": "Au revoir" }
        ]
      }.to_json
    end

    before do
      allow(mock_client).to receive(:complete).and_return(bulk_response)
    end

    it "translates multiple texts" do
      texts = %w[Hello Goodbye]
      result = translator.translate_batch(texts, from: "en", to: "fr")

      expect(result).to eq({
                             0 => "Bonjour",
                             1 => "Au revoir"
                           })
    end

    it "handles large batches by splitting" do
      large_texts = Array.new(25) { |i| "Text #{i}" }

      # Doit faire 3 appels (10 + 10 + 5)
      expect(mock_client).to receive(:complete).exactly(3).times
      expect(translator).to receive(:sleep).twice # Entre les batches

      translator.translate_batch(large_texts, from: "en", to: "fr")
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
    let(:detection_response) { '{"detected_language": "fr"}' }
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

    it "uses english as fallback for detection errors" do
      allow(mock_client).to receive(:complete)
        .and_return("invalid json", translation_response)

      # Ne doit pas lever d'erreur, utilise 'en' par défaut
      expect { translator.translate_auto("Hello", to: "fr") }.not_to raise_error
    end
  end

  describe "private methods" do
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
  end
end

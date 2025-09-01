# frozen_string_literal: true

RSpec.describe MistralTranslator::Summarizer do
  let(:mock_client) { instance_double(MistralTranslator::Client) }
  let(:summarizer) { described_class.new(client: mock_client) }
  let(:long_text) { "This is a very long text that needs to be summarized for testing purposes. " * 5 }

  # Configuration pour debug
  before do
    ENV["MISTRAL_TRANSLATOR_DEBUG"] = "true"
  end

  after do
    ENV.delete("MISTRAL_TRANSLATOR_DEBUG")
  end

  describe "#initialize" do
    it "uses provided client" do
      expect(summarizer.instance_variable_get(:@client)).to eq(mock_client)
    end

    it "creates default client when none provided" do
      default_summarizer = described_class.new
      expect(default_summarizer.instance_variable_get(:@client)).to be_a(MistralTranslator::Client)
    end
  end

  describe "#summarize" do
    let(:summary_response) do
      {
        "content": {
          "source": long_text,
          "target": "This is a short summary"
        },
        "metadata": {
          "max_words": 250,
          "language": "fr"
        }
      }.to_json
    end

    before do
      allow(mock_client).to receive(:complete).and_return(summary_response)
    end

    it "summarizes text successfully" do
      result = summarizer.summarize(long_text, language: "fr", max_words: 100)
      expect(result).to eq("This is a short summary")
    end

    it "uses default parameters correctly" do
      # Mock PromptBuilder pour vérifier les paramètres
      allow(MistralTranslator::PromptBuilder).to receive(:summary_prompt)
        .with(anything, 250, "fr")
        .and_return("mocked prompt")

      allow(mock_client).to receive(:complete).with("mocked prompt").and_return(summary_response)

      result = summarizer.summarize(long_text)
      expect(result).to eq("This is a short summary")
    end

    it "validates and normalizes locale" do
      expect(MistralTranslator::LocaleHelper).to receive(:validate_locale!)
        .with("fr")
        .and_return("fr")

      summarizer.summarize(long_text, language: "fr")
    end

    it "cleans document content before processing" do
      messy_text = "Text   with    multiple\n\n\nspaces\n\n   and   newlines   "

      # Le texte nettoyé devrait avoir des espaces simples et préserver la structure des lignes
      expected_cleaned = "Text with multiple\nspaces\nand newlines"

      expect(MistralTranslator::PromptBuilder).to receive(:summary_prompt)
        .with(expected_cleaned, 250, "fr")
        .and_return("prompt")

      summarizer.summarize(messy_text, language: "fr")
    end

    context "with validation errors" do
      it "raises ArgumentError for nil text" do
        expect { summarizer.summarize(nil) }.to raise_error(
          ArgumentError, "Text cannot be nil or empty"
        )
      end

      it "raises ArgumentError for empty text" do
        expect { summarizer.summarize("") }.to raise_error(
          ArgumentError, "Text cannot be nil or empty"
        )
      end

      it "raises ArgumentError for invalid max_words" do
        expect { summarizer.summarize(long_text, max_words: 0) }.to raise_error(
          ArgumentError, "Max words must be a positive integer"
        )

        expect { summarizer.summarize(long_text, max_words: "invalid") }.to raise_error(
          ArgumentError, "Max words must be a positive integer"
        )
      end
    end

    context "with API errors and retries" do
      it "retries on EmptyTranslationError then succeeds" do
        # Premier appel échoue, deuxième réussit
        call_count = 0
        allow(mock_client).to receive(:complete) do
          call_count += 1
          raise MistralTranslator::EmptyTranslationError if call_count == 1

          summary_response
        end

        result = summarizer.summarize(long_text)
        expect(result).to eq("This is a short summary")
        expect(call_count).to eq(2)
      end

      it "raises error after max retries" do
        allow(mock_client).to receive(:complete)
          .and_raise(MistralTranslator::EmptyTranslationError)
          .exactly(4).times # 1 tentative initiale + 3 retries

        expect { summarizer.summarize(long_text) }.to raise_error(
          MistralTranslator::EmptyTranslationError
        )
      end

      it "retries indefinitely on RateLimitError" do
        call_count = 0
        allow(mock_client).to receive(:complete) do
          call_count += 1
          raise MistralTranslator::RateLimitError if call_count < 3

          summary_response
        end

        result = summarizer.summarize(long_text)
        expect(result).to eq("This is a short summary")
        expect(call_count).to eq(3)
      end
    end
  end

  describe "#summarize_and_translate" do
    let(:translated_summary_response) do
      {
        "content": {
          "source": long_text,
          "target": "This is a translated summary"
        }
      }.to_json
    end

    before do
      allow(mock_client).to receive(:complete).and_return(translated_summary_response)
    end

    it "summarizes and translates in one call" do
      result = summarizer.summarize_and_translate(long_text, from: "fr", to: "en", max_words: 100)
      expect(result).to eq("This is a translated summary")
    end

    it "delegates to simple summarize when same language" do
      expect(summarizer).to receive(:summarize)
        .with(anything, language: "fr", max_words: 100)
        .and_return("Summary in same language")

      result = summarizer.summarize_and_translate(long_text, from: "fr", to: "fr", max_words: 100)
      expect(result).to eq("Summary in same language")
    end

    it "validates required inputs" do
      expect { summarizer.summarize_and_translate("", from: "fr", to: "en") }.to raise_error(ArgumentError)
      expect { summarizer.summarize_and_translate(long_text, from: nil, to: "en") }.to raise_error(ArgumentError)
    end
  end

  describe "#summarize_to_multiple" do
    let(:french_summary) { '{"content": {"target": "Résumé français"}}' }
    let(:english_summary) { '{"content": {"target": "English summary"}}' }

    before do
      # Configurer les réponses dans l'ordre
      allow(mock_client).to receive(:complete)
        .and_return(french_summary, english_summary)
    end

    it "creates summaries in multiple languages" do
      result = summarizer.summarize_to_multiple(long_text, languages: %w[fr en], max_words: 100)

      expect(result).to eq({
                             "fr" => "Résumé français",
                             "en" => "English summary"
                           })
    end

    it "adds delay only between requests (not before first)" do
      # On s'attend à un seul sleep car il y a 2 langues (delay entre fr et en)
      expect(summarizer).to receive(:sleep).with(2).once

      summarizer.summarize_to_multiple(long_text, languages: %w[fr en])
    end

    it "handles single language as string" do
      result = summarizer.summarize_to_multiple(long_text, languages: "fr")
      expect(result).to eq({ "fr" => "Résumé français" })
    end

    it "handles single language as array" do
      result = summarizer.summarize_to_multiple(long_text, languages: ["fr"])
      expect(result).to eq({ "fr" => "Résumé français" })
    end

    it "validates inputs" do
      expect { summarizer.summarize_to_multiple(long_text, languages: []) }.to raise_error(
        ArgumentError, "Languages array cannot be empty"
      )
    end
  end

  describe "#summarize_tiered" do
    let(:short_response) { '{"content": {"target": "Short"}}' }
    let(:medium_response) { '{"content": {"target": "Medium summary"}}' }
    let(:long_response) { '{"content": {"target": "Long detailed summary"}}' }

    before do
      allow(mock_client).to receive(:complete)
        .and_return(short_response, medium_response, long_response)
    end

    it "creates tiered summaries with custom lengths" do
      result = summarizer.summarize_tiered(long_text, language: "fr", short: 25, medium: 100, long: 200)

      expect(result).to eq({
                             short: "Short",
                             medium: "Medium summary",
                             long: "Long detailed summary"
                           })
    end

    it "uses default values correctly" do
      result = summarizer.summarize_tiered(long_text)

      expect(result).to have_key(:short)
      expect(result).to have_key(:medium)
      expect(result).to have_key(:long)
      expect(result[:short]).to eq("Short")
      expect(result[:medium]).to eq("Medium summary")
      expect(result[:long]).to eq("Long detailed summary")
    end

    it "validates length progression" do
      expect { summarizer.summarize_tiered(long_text, short: 100, medium: 50, long: 200) }.to raise_error(
        ArgumentError, "Medium length must be greater than short"
      )

      expect { summarizer.summarize_tiered(long_text, short: 50, medium: 100, long: 75) }.to raise_error(
        ArgumentError, "Long length must be greater than medium"
      )
    end
  end

  describe "private methods" do
    describe "#clean_document_content" do
      it "handles simple text cleaning" do
        simple_text = "Text   with    multiple spaces"
        expected = "Text with multiple spaces"

        result = summarizer.send(:clean_document_content, simple_text)
        expect(result).to eq(expected)
      end

      it "preserves single newlines while cleaning spaces" do
        text_with_newlines = "Line one\nLine two\nLine three"
        result = summarizer.send(:clean_document_content, text_with_newlines)
        expect(result).to eq("Line one\nLine two\nLine three")
      end

      it "removes multiple newlines" do
        text_with_multiple_newlines = "Line one\n\n\nLine two"
        expected = "Line one\nLine two"

        result = summarizer.send(:clean_document_content, text_with_multiple_newlines)
        expect(result).to eq(expected)
      end

      it "removes line separators and cleans spaces" do
        text_with_separators = "Text\n-----\nMore text\n----------\nEnd"
        expected = "Text\nMore text\nEnd"

        result = summarizer.send(:clean_document_content, text_with_separators)
        expect(result).to eq(expected)
        expect(result).not_to include("-----")
        expect(result).not_to include("----------")
      end

      it "handles complex mixed formatting" do
        messy_text = "Start   text\n\n\n   with   ---   separators   \n\nand    more   text\n\n"
        expected = "Start text\nwith separators\nand more text"

        result = summarizer.send(:clean_document_content, messy_text)
        expect(result).to eq(expected)
      end

      it "handles nil input" do
        result = summarizer.send(:clean_document_content, nil)
        expect(result).to be_nil
      end

      it "handles empty string" do
        result = summarizer.send(:clean_document_content, "")
        expect(result).to eq("")
      end
    end

    describe "#build_summary_translation_prompt" do
      it "builds correct prompt for summary and translation" do
        prompt = summarizer.send(:build_summary_translation_prompt, "Sample text", "fr", "en", 100)

        expect(prompt).to include("français")
        expect(prompt).to include("english")
        expect(prompt).to include("100 mots")
        expect(prompt).to include("summarize_and_translate")
        expect(prompt).to include("Sample text")
      end
    end

    describe "validation methods" do
      describe "#validate_summarize_inputs!" do
        it "validates all required inputs" do
          # Nil text
          expect { summarizer.send(:validate_summarize_inputs!, nil, "fr", 100) }.to raise_error(
            ArgumentError, "Text cannot be nil or empty"
          )

          # Empty text
          expect { summarizer.send(:validate_summarize_inputs!, "", "fr", 100) }.to raise_error(
            ArgumentError, "Text cannot be nil or empty"
          )

          # Nil language
          expect { summarizer.send(:validate_summarize_inputs!, "text", nil, 100) }.to raise_error(
            ArgumentError, "Language cannot be nil"
          )

          # Invalid max_words
          expect { summarizer.send(:validate_summarize_inputs!, "text", "fr", 0) }.to raise_error(
            ArgumentError, "Max words must be a positive integer"
          )

          expect { summarizer.send(:validate_summarize_inputs!, "text", "fr", -1) }.to raise_error(
            ArgumentError, "Max words must be a positive integer"
          )

          expect { summarizer.send(:validate_summarize_inputs!, "text", "fr", "not_integer") }.to raise_error(
            ArgumentError, "Max words must be a positive integer"
          )
        end

        it "passes with valid inputs" do
          expect { summarizer.send(:validate_summarize_inputs!, "text", "fr", 100) }.not_to raise_error
        end
      end

      describe "#validate_multiple_summarize_inputs!" do
        it "validates languages array" do
          expect { summarizer.send(:validate_multiple_summarize_inputs!, "text", [], 100) }.to raise_error(
            ArgumentError, "Languages array cannot be empty"
          )
        end

        it "handles single language as string" do
          expect { summarizer.send(:validate_multiple_summarize_inputs!, "text", "fr", 100) }.not_to raise_error
        end

        it "handles languages as array" do
          expect { summarizer.send(:validate_multiple_summarize_inputs!, "text", %w[fr en], 100) }.not_to raise_error
        end
      end

      describe "#validate_tiered_inputs!" do
        it "validates length progression" do
          # Medium pas plus grand que short
          expect { summarizer.send(:validate_tiered_inputs!, "text", "fr", 100, 50, 200) }.to raise_error(
            ArgumentError, "Medium length must be greater than short"
          )

          # Long pas plus grand que medium
          expect { summarizer.send(:validate_tiered_inputs!, "text", "fr", 50, 100, 75) }.to raise_error(
            ArgumentError, "Long length must be greater than medium"
          )
        end

        it "passes with valid progression" do
          expect { summarizer.send(:validate_tiered_inputs!, "text", "fr", 50, 100, 200) }.not_to raise_error
        end
      end
    end

    describe "logging methods" do
      describe "#log_debug" do
        it "logs debug messages when debug enabled" do
          ENV["MISTRAL_TRANSLATOR_TEST_OUTPUT"] = "true"
          expect { summarizer.send(:log_debug, "test message") }.to output(
            /\[MistralTranslator\] test message/
          ).to_stdout
          ENV["MISTRAL_TRANSLATOR_TEST_OUTPUT"] = nil
        end
      end
    end
  end
end

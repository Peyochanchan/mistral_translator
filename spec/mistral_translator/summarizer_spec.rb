# frozen_string_literal: true

RSpec.describe MistralTranslator::Summarizer do
  let(:mock_client) { instance_double(MistralTranslator::Client) }
  let(:summarizer) { described_class.new(client: mock_client) }
  let(:long_text) { "This is a very long text that needs to be summarized for testing purposes. " * 10 }

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

    it "uses default parameters" do
      expect(MistralTranslator::PromptBuilder).to receive(:summary_prompt)
        .with(anything, 250, "fr")
        .and_return("mocked prompt")

      summarizer.summarize(long_text)
    end

    it "validates locale" do
      expect(MistralTranslator::LocaleHelper).to receive(:validate_locale!).with("fr").and_return("fr")

      summarizer.summarize(long_text, language: "fr")
    end

    it "cleans document content" do
      messy_text = "Text   with    multiple\n\n\nspaces\n\n   and   newlines   "
      cleaned_expectation = "Text with multiple\nspaces and newlines"

      expect(MistralTranslator::PromptBuilder).to receive(:summary_prompt)
        .with(cleaned_expectation, 250, "fr")
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
      it "retries on EmptyTranslationError" do
        allow(mock_client).to receive(:complete)
          .and_raise(MistralTranslator::EmptyTranslationError)
          .once
        allow(mock_client).to receive(:complete)
          .and_return(summary_response)
          .once

        result = summarizer.summarize(long_text)
        expect(result).to eq("This is a short summary")
      end

      it "raises error after max retries" do
        allow(mock_client).to receive(:complete)
          .and_raise(MistralTranslator::EmptyTranslationError)
          .exactly(4).times

        expect { summarizer.summarize(long_text) }.to raise_error(
          MistralTranslator::EmptyTranslationError
        )
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

    it "just summarizes when same language" do
      expect(summarizer).to receive(:summarize)
        .with(anything, language: "fr", max_words: 100)
        .and_return("Summary in same language")

      result = summarizer.summarize_and_translate(long_text, from: "fr", to: "fr", max_words: 100)
      expect(result).to eq("Summary in same language")
    end

    it "validates inputs" do
      expect { summarizer.summarize_and_translate("", from: "fr", to: "en") }.to raise_error(ArgumentError)
      expect { summarizer.summarize_and_translate(long_text, from: nil, to: "en") }.to raise_error(ArgumentError)
    end
  end

  describe "#summarize_to_multiple" do
    let(:french_summary) { '{"content": {"target": "Résumé français"}}' }
    let(:english_summary) { '{"content": {"target": "English summary"}}' }

    before do
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

    it "adds delay between requests" do
      expect(summarizer).to receive(:sleep).with(2).once

      summarizer.summarize_to_multiple(long_text, languages: %w[fr en])
    end

    it "handles single language" do
      result = summarizer.summarize_to_multiple(long_text, languages: "fr")
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

    it "creates tiered summaries" do
      result = summarizer.summarize_tiered(long_text, language: "fr", short: 25, medium: 100, long: 200)

      expect(result).to eq({
                             short: "Short",
                             medium: "Medium summary",
                             long: "Long detailed summary"
                           })
    end

    it "uses default values" do
      result = summarizer.summarize_tiered(long_text)

      expect(result).to have_key(:short)
      expect(result).to have_key(:medium)
      expect(result).to have_key(:long)
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
      it "cleans up text formatting" do
        messy_text = "Text  with    multiple\n\n\nlines\n\n   and   ---   separators   "
        expected = "Text with multiple\nlines and separators"

        result = summarizer.send(:clean_document_content, messy_text)
        expect(result).to eq(expected)
      end

      it "handles nil input" do
        result = summarizer.send(:clean_document_content, nil)
        expect(result).to be_nil
      end

      it "removes line separators" do
        text_with_separators = "Text\n-----\nMore text\n----------\nEnd"
        result = summarizer.send(:clean_document_content, text_with_separators)
        expect(result).not_to include("-----")
        expect(result).not_to include("----------")
      end
    end

    describe "#build_summary_translation_prompt" do
      it "builds correct prompt for summary and translation" do
        prompt = summarizer.send(:build_summary_translation_prompt, "Text", "fr", "en", 100)

        expect(prompt).to include("français")
        expect(prompt).to include("english")
        expect(prompt).to include("100 mots")
        expect(prompt).to include("summarize_and_translate")
      end
    end

    describe "validation methods" do
      describe "#validate_summarize_inputs!" do
        it "validates basic summarize inputs" do
          expect { summarizer.send(:validate_summarize_inputs!, nil, "fr", 100) }.to raise_error(ArgumentError)
          expect { summarizer.send(:validate_summarize_inputs!, "", "fr", 100) }.to raise_error(ArgumentError)
          expect { summarizer.send(:validate_summarize_inputs!, "text", nil, 100) }.to raise_error(ArgumentError)
          expect { summarizer.send(:validate_summarize_inputs!, "text", "fr", 0) }.to raise_error(ArgumentError)
          expect { summarizer.send(:validate_summarize_inputs!, "text", "fr", -1) }.to raise_error(ArgumentError)
        end
      end

      describe "#validate_tiered_inputs!" do
        it "validates tiered length progression" do
          expect { summarizer.send(:validate_tiered_inputs!, "text", "fr", 100, 50, 200) }.to raise_error(ArgumentError)
          expect { summarizer.send(:validate_tiered_inputs!, "text", "fr", 50, 100, 75) }.to raise_error(ArgumentError)
        end

        it "passes with valid progression" do
          expect { summarizer.send(:validate_tiered_inputs!, "text", "fr", 50, 100, 200) }.not_to raise_error
        end
      end
    end
  end
end

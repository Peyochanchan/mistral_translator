# frozen_string_literal: true

RSpec.describe MistralTranslator::ResponseParser do
  describe ".parse_translation_response" do
    context "with valid JSON response" do
      let(:valid_json) do
        {
          content: {
            source: "Hello",
            target: "Bonjour"
          },
          metadata: {
            source: "en",
            target: "fr"
          }
        }.to_json
      end

      it "parses standard format correctly" do
        result = described_class.parse_translation_response(valid_json)

        expect(result).to eq({
                               original: "Hello",
                               translated: "Bonjour",
                               metadata: {
                                 "source" => "en",
                                 "target" => "fr"
                               }
                             })
      end

      it "extracts JSON from text with surrounding content" do
        content_with_text = "Here is the translation: #{valid_json} Hope this helps!"
        result = described_class.parse_translation_response(content_with_text)

        expect(result[:translated]).to eq("Bonjour")
        expect(result[:original]).to eq("Hello")
      end
    end

    context "with alternative JSON formats" do
      it "handles translation.target format" do
        alt_json = {
          translation: {
            source: "Hello",
            target: "Bonjour"
          }
        }.to_json

        result = described_class.parse_translation_response(alt_json)
        expect(result[:translated]).to eq("Bonjour")
        expect(result[:original]).to eq("Hello")
      end

      it "handles direct target format" do
        simple_json = {
          target: "Bonjour",
          source: "Hello"
        }.to_json

        result = described_class.parse_translation_response(simple_json)
        expect(result[:translated]).to eq("Bonjour")
        expect(result[:original]).to eq("Hello")
      end

      it "handles translated format" do
        translated_json = {
          content: {
            original: "Hello",
            translated: "Bonjour"
          }
        }.to_json

        result = described_class.parse_translation_response(translated_json)
        expect(result[:translated]).to eq("Bonjour")
        expect(result[:original]).to eq("Hello")
      end
    end

    context "with invalid responses" do
      it "returns nil for invalid JSON format" do
        expect(described_class.parse_translation_response("{invalid json")).to be_nil
      end

      it "returns nil for nil input" do
        expect(described_class.parse_translation_response(nil)).to be_nil
      end

      it "returns nil for empty input" do
        expect(described_class.parse_translation_response("")).to be_nil
      end

      it "returns nil when no JSON found" do
        expect(described_class.parse_translation_response("No JSON here!")).to be_nil
      end

      it "raises EmptyTranslationError for empty target" do
        empty_json = {
          content: {
            source: "Hello",
            target: ""
          }
        }.to_json

        expect { described_class.parse_translation_response(empty_json) }.to raise_error(
          MistralTranslator::EmptyTranslationError
        )
      end

      it "raises EmptyTranslationError for nil target" do
        nil_json = {
          content: {
            source: "Hello",
            target: nil
          }
        }.to_json

        expect { described_class.parse_translation_response(nil_json) }.to raise_error(
          MistralTranslator::EmptyTranslationError
        )
      end
    end
  end

  describe ".parse_summary_response" do
    let(:valid_summary_json) do
      {
        content: {
          source: "Very long text that needs to be summarized...",
          target: "Short summary"
        },
        metadata: {
          max_words: 50,
          language: "fr"
        }
      }.to_json
    end

    it "parses summary response correctly" do
      result = described_class.parse_summary_response(valid_summary_json)

      expect(result).to eq({
                             original: "Very long text that needs to be summarized...",
                             summary: "Short summary",
                             metadata: {
                               "max_words" => 50,
                               "language" => "fr"
                             }
                           })
    end

    it "handles empty summary" do
      empty_summary = {
        content: {
          source: "Text",
          target: ""
        }
      }.to_json

      expect { described_class.parse_summary_response(empty_summary) }.to raise_error(
        MistralTranslator::EmptyTranslationError,
        "Empty summary received"
      )
    end

    it "returns nil for invalid input" do
      expect(described_class.parse_summary_response(nil)).to be_nil
      expect(described_class.parse_summary_response("")).to be_nil
    end
  end

  describe ".parse_bulk_translation_response" do
    let(:valid_bulk_json) do
      {
        translations: [
          {
            index: 1,
            source: "Hello",
            target: "Bonjour"
          },
          {
            index: 2,
            source: "Goodbye",
            target: "Au revoir"
          }
        ],
        metadata: {
          source_language: "en",
          target_language: "fr",
          count: 2
        }
      }.to_json
    end

    it "parses bulk translation response correctly" do
      result = described_class.parse_bulk_translation_response(valid_bulk_json)

      expect(result).to eq([
                             {
                               index: 1,
                               original: "Hello",
                               translated: "Bonjour"
                             },
                             {
                               index: 2,
                               original: "Goodbye",
                               translated: "Au revoir"
                             }
                           ])
    end

    it "raises InvalidResponseError when no translations array" do
      invalid_json = {
        content: {
          target: "Something"
        }
      }.to_json

      expect { described_class.parse_bulk_translation_response(invalid_json) }.to raise_error(
        MistralTranslator::InvalidResponseError,
        "No translations array in response"
      )
    end

    it "returns empty array for invalid input" do
      expect(described_class.parse_bulk_translation_response(nil)).to eq([])
      expect(described_class.parse_bulk_translation_response("")).to eq([])
    end

    it "handles malformed bulk response" do
      expect { described_class.parse_bulk_translation_response("invalid json") }.to raise_error(
        MistralTranslator::InvalidResponseError,
        /Invalid JSON in bulk response/
      )
    end
  end

  describe "private methods" do
    describe ".extract_json_from_content" do
      it "extracts JSON from mixed content" do
        content = 'Some text {"key": "value"} more text'
        json = described_class.send(:extract_json_from_content, content)
        expect(json).to eq('{"key": "value"}')
      end

      it "extracts complex JSON" do
        complex_json = '{"nested": {"key": "value"}, "array": [1, 2, 3]}'
        content = "Response: #{complex_json} End"
        json = described_class.send(:extract_json_from_content, content)
        expect(json).to eq(complex_json)
      end

      it "extracts JSON with escaped quotes in HTML content" do
        complex_json = '{
          "content": {
            "source": "<div class=\"trix-content\"><div>Una asociación para promover la alfabetización digital " \
                      "y garantizar el acceso equitativo a la tecnología para todas las comunidades. " \
                      "<strong>Fomentamos la innovación para empoderar a una sociedad global conectada.</strong>" \
                      "</div></div>",
            "target": "<div class=\"trix-content\"><div>A association to promote digital literacy " \
                      "and ensure equitable access to technology for all communities. " \
                      "<strong>We foster innovation to empower a connected global society.</strong>" \
                      "</div></div>"
          },
          "metadata": {
            "source_language": "es",
            "target_language": "en",
            "operation": "translation"
          }
        }'
        content = "Response: #{complex_json} End"
        json = described_class.send(:extract_json_from_content, content)
        expect(json).to eq(complex_json)
      end

      it "returns nil when no JSON found" do
        json = described_class.send(:extract_json_from_content, "No JSON here")
        expect(json).to be_nil
      end
    end

    context "with real-world problematic JSON" do
      it "parses the exact JSON from the error case" do
        problematic_json = '{
  "content": {
    "source": "<div class=\\"trix-content\\"><div>Una asociación para promover la alfabetización digital " \
              "y garantizar el acceso equitativo a la tecnología para todas las comunidades. " \
              "<strong>Fomentamos la innovación para empoderar a una sociedad global conectada.</strong>" \
              "</div></div>",
    "target": "<div class=\\"trix-content\\"><div>A association to promote digital literacy " \
              "and ensure equitable access to technology for all communities. " \
              "<strong>We foster innovation to empower a connected global society.</strong>" \
              "</div></div>"
  },
  "metadata": {
    "source_language": "es",
    "target_language": "en",
    "operation": "translation"
  }
}'

        result = described_class.parse_translation_response(problematic_json)

        expect(result).to be_a(Hash)
        expect(result[:translated]).to include("A association to promote digital literacy")
        expect(result[:original]).to include("Una asociación para promover la alfabetización digital")
        expect(result[:metadata]["source_language"]).to eq("es")
        expect(result[:metadata]["target_language"]).to eq("en")
      end

      it "handles JSON with complex nested quotes and HTML" do
        complex_json = '{
  "content": {
    "source": "<div class=\\"trix-content\\"><div>Text with \\"quotes\\" and <strong>HTML</strong></div></div>",
    "target": "<div class=\\"trix-content\\"><div>Texte avec \\"guillemets\\" et <strong>HTML</strong></div></div>"
  },
  "metadata": {
    "source_language": "en",
    "target_language": "fr"
  }
}'

        result = described_class.parse_translation_response(complex_json)

        expect(result).to be_a(Hash)
        expect(result[:translated]).to include("Texte avec")
        expect(result[:original]).to include("Text with")
      end

      it "provides secure error information when JSON parsing fails" do
        invalid_json = '{"invalid": json, "missing": quotes}'

        expect { described_class.parse_translation_response(invalid_json) }.to raise_error(
          MistralTranslator::InvalidResponseError,
          /Invalid JSON in response.*Details:/
        )
      end

      it "rejects content that is too large" do
        large_content = "x" * 1_000_001 # Plus de 1MB

        expect { described_class.parse_translation_response(large_content) }.to raise_error(
          MistralTranslator::InvalidResponseError,
          /Response content too large/
        )
      end

      it "handles malformed JSON that could cause infinite loops" do
        # Créer un JSON qui passera le premier parsing mais causera des problèmes dans find_json_in_text
        # En entourant le JSON malformé de texte pour forcer l'utilisation de find_json_in_text
        malformed_json = "Some text before {#{"{" * 50_000}#{"}" * 50_000}} some text after"

        expect { described_class.parse_translation_response(malformed_json) }.to raise_error(
          MistralTranslator::InvalidResponseError,
          /JSON parsing exceeded maximum iterations/
        )
      end
    end

    describe ".extract_target_content" do
      it "finds content.target" do
        data = { "content" => { "target" => "Found!" } }
        result = described_class.send(:extract_target_content, data)
        expect(result).to eq("Found!")
      end

      it "finds translation.target" do
        data = { "translation" => { "target" => "Found!" } }
        result = described_class.send(:extract_target_content, data)
        expect(result).to eq("Found!")
      end

      it "finds direct target" do
        data = { "target" => "Found!" }
        result = described_class.send(:extract_target_content, data)
        expect(result).to eq("Found!")
      end

      it "prioritizes content.target over others" do
        data = {
          "content" => { "target" => "Priority!" },
          "target" => "Secondary"
        }
        result = described_class.send(:extract_target_content, data)
        expect(result).to eq("Priority!")
      end

      it "returns nil when no target found" do
        data = { "other" => "value" }
        result = described_class.send(:extract_target_content, data)
        expect(result).to be_nil
      end
    end
  end
end

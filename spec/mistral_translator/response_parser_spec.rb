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
      it "raises for an incomplete JSON" do
        expect { described_class.parse_translation_response("{invalid json") }
          .to raise_error(MistralTranslator::InvalidResponseError, /No JSON in translation response/)
      end

      it "returns nil for nil input" do
        expect(described_class.parse_translation_response(nil)).to be_nil
      end

      it "returns nil for empty input" do
        expect(described_class.parse_translation_response("")).to be_nil
      end

      it "raises when no JSON is found" do
        expect { described_class.parse_translation_response("No JSON here!") }
          .to raise_error(MistralTranslator::InvalidResponseError, /No JSON in translation response/)
      end

      it "raises for a JSON array" do
        expect { described_class.parse_translation_response('[{"target": "Bonjour"}]') }
          .to raise_error(MistralTranslator::InvalidResponseError)
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

  describe "nested JSON in target" do
    it "unwraps a serialized response object found in target" do
      nested = { content: { source: "Hello", target: "Bonjour + merci" } }.to_json
      response = { content: { source: "Hello", target: nested } }.to_json

      result = described_class.parse_translation_response(response)
      expect(result[:translated]).to eq("Bonjour + merci")
    end

    it "keeps a target that only starts with a brace" do
      response = { content: { source: "{x}", target: "{x} est une variable" } }.to_json

      result = described_class.parse_translation_response(response)
      expect(result[:translated]).to eq("{x} est une variable")
    end

    it "unwraps a response object nested as a Hash" do
      response = { content: { target: { content: { target: "Salama" } } } }.to_json

      expect(described_class.parse_translation_response(response)[:translated]).to eq("Salama")
    end

    it "rejects a target that is neither text nor a response object" do
      [{ text: "Bonjour" }, ["Bonjour"], 42].each do |target|
        expect { described_class.parse_translation_response({ content: { target: target } }.to_json) }
          .to raise_error(MistralTranslator::InvalidResponseError, /Unexpected target/)
      end
    end

    it "treats a blank target as empty" do
      expect { described_class.parse_translation_response({ content: { target: " \n " } }.to_json) }
        .to raise_error(MistralTranslator::EmptyTranslationError)
    end

    it "treats an empty nested target as empty" do
      nested = { content: { target: "" } }.to_json

      expect { described_class.parse_translation_response({ content: { target: nested } }.to_json) }
        .to raise_error(MistralTranslator::EmptyTranslationError)
    end

    it "does not keep the original error as cause" do
      expect { described_class.parse_translation_response('{"content": {"target": x}}') }
        .to raise_error(MistralTranslator::InvalidResponseError) { |error| expect(error.cause).to be_nil }
    end

    it "ignores source and metadata that are not objects" do
      result = described_class.parse_translation_response('{"content": "texte", "metadata": "x", "target": "Bonjour"}')

      expect(result).to eq(original: nil, translated: "Bonjour", metadata: {})
    end

    it "validates the quality check translation" do
      expect { described_class.parse_quality_check_response('{"metadata": {}}') }
        .to raise_error(MistralTranslator::EmptyTranslationError)
    end

    it "keeps a JSON target without a known key" do
      target = { "a" => 1 }.to_json
      response = { content: { source: "Hello", target: target } }.to_json

      result = described_class.parse_translation_response(response)
      expect(result[:translated]).to eq(target)
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

    it "rejects a raw text response" do
      expect { described_class.parse_summary_response("Un résumé sans JSON") }.to raise_error(
        MistralTranslator::InvalidResponseError
      )
    end

    it "returns nil for invalid input" do
      expect(described_class.parse_summary_response(nil)).to be_nil
      expect(described_class.parse_summary_response("")).to be_nil
    end
  end

  describe "private methods" do
    describe ".find_json_in_text" do
      it "extracts JSON from mixed content" do
        content = 'Some text {"key": "value"} more text'
        json = described_class.send(:find_json_in_text, content)
        expect(json).to eq('{"key": "value"}')
      end

      it "extracts complex JSON" do
        complex_json = '{"nested": {"key": "value"}, "array": [1, 2, 3]}'
        content = "Response: #{complex_json} End"
        json = described_class.send(:find_json_in_text, content)
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
        json = described_class.send(:find_json_in_text, content)
        expect(json).to eq(complex_json)
      end

      it "returns nil when no JSON found" do
        json = described_class.send(:find_json_in_text, "No JSON here")
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
          /Invalid JSON in translation response \(raw_len=\d+ json_len=\d+\)/
        )
      end

      it "keeps the response out of the message but available to the caller" do
        invalid_json = '{"secret_text": confidentiel}'

        expect { described_class.parse_translation_response(invalid_json) }.to raise_error(
          MistralTranslator::InvalidResponseError
        ) { |error|
          expect(error.message).not_to include("confidentiel")
          expect(error.raw_response).to eq(invalid_json)
        }
      end

      it "keeps summary responses out of error messages" do
        expect { described_class.parse_summary_response("Texte confidentiel") }.to raise_error(
          MistralTranslator::InvalidResponseError
        ) { |error| expect(error.message).not_to include("confidentiel") }
      end

      it "drops the parser error, which quotes the response, from the cause chain" do
        ["Texte confidentiel", "Texte confidentiel {\"target\": ", "{#{"{" * 100_000}"].each do |raw|
          expect { described_class.parse_translation_response(raw) }.to raise_error(
            MistralTranslator::InvalidResponseError
          ) { |error| expect(error.cause).to be_nil }
        end
      end

      it "rejects content that is too large" do
        large_content = "x" * 1_000_001 # Plus de 1MB

        expect { described_class.parse_translation_response(large_content) }.to raise_error(
          MistralTranslator::InvalidResponseError,
          /Response content too large/
        )
      end

      it "handles malformed JSON that could cause infinite loops" do
        # Du texte autour du JSON force la recherche dans le texte, plafonnée
        malformed_json = "Some text before {#{"{" * 50_000}#{"}" * 50_000}} some text after"

        expect { described_class.parse_translation_response(malformed_json) }.to raise_error(
          MistralTranslator::InvalidResponseError,
          /JSON parsing exceeded maximum iterations/
        )
      end
    end

    describe ".find_target" do
      it "finds content.target" do
        expect(described_class.send(:find_target, { "content" => { "target" => "Found!" } })).to eq("Found!")
      end

      it "finds translation.target" do
        expect(described_class.send(:find_target, { "translation" => { "target" => "Found!" } })).to eq("Found!")
      end

      it "finds direct target" do
        expect(described_class.send(:find_target, { "target" => "Found!" })).to eq("Found!")
      end

      it "prioritizes content.target over others" do
        data = { "content" => { "target" => "Priority!" }, "target" => "Secondary" }
        expect(described_class.send(:find_target, data)).to eq("Priority!")
      end

      it "returns nil when no target found" do
        expect(described_class.send(:find_target, { "other" => "value" })).to be_nil
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe MistralTranslator::PromptBuilder do
  describe ".translation_prompt" do
    it "accepts a glossary given as a string" do
      prompt = described_class.translation_prompt("Hi", "en", "fr", glossary: "API = API")

      expect(prompt).to include('"has_glossary": true')
    end

    it "flags a non-empty glossary hash" do
      prompt = described_class.translation_prompt("Hi", "en", "fr", glossary: { "API" => "API" })

      expect(prompt).to include('"has_glossary": true')
    end

    it "does not flag an empty glossary" do
      expect(described_class.translation_prompt("Hi", "en", "fr", glossary: {})).not_to include("has_glossary")
      expect(described_class.translation_prompt("Hi", "en", "fr", glossary: " ")).not_to include("has_glossary")
    end
  end
end

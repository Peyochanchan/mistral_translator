# frozen_string_literal: true

require_relative "logger"

module MistralTranslator
  module PromptMetadataHelpers
    QUALITY_CHECK_METADATA = <<~JSON.chomp.gsub("\n", "\n    ")
      "quality_check": {
        "terminology_consistency": "vérifié",
        "style_preservation": "vérifié",
        "completeness": "vérifié"
      }
    JSON

    # context_present? et glossary_present? viennent de PromptHelpers::ContextBuilder
    def build_metadata_additions(context, glossary, preserve_html, quality_check: false)
      additions = []

      additions << '"has_context": true' if context_present?(context)
      additions << '"has_glossary": true' if glossary_present?(glossary)
      additions << '"preserve_html": true' if preserve_html
      additions << QUALITY_CHECK_METADATA if quality_check

      additions.any? ? ",\n    #{additions.join(",\n    ")}" : ""
    end

    def build_summary_metadata_additions(context, style)
      additions = []

      additions << '"has_context": true' if context_present?(context)
      additions << %("style": "#{style}") if style && !style.to_s.strip.empty?

      additions.any? ? ",\n    #{additions.join(",\n    ")}" : ""
    end
  end
end

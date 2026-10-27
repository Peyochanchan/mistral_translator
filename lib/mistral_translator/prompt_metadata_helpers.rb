# frozen_string_literal: true

require_relative "logger"

module MistralTranslator
  module PromptMetadataHelpers
    def build_metadata_additions(context, glossary, preserve_html)
      additions = []

      additions << '"has_context": true' if context && !context.to_s.strip.empty?
      additions << '"has_glossary": true' if glossary_present?(glossary)
      additions << '"preserve_html": true' if preserve_html

      additions.any? ? ",\n              #{additions.join(",\n              ")}" : ""
    end

    def build_summary_metadata_additions(context, style)
      additions = []

      additions << '"has_context": true' if context && !context.to_s.strip.empty?
      additions << %("style": "#{style}") if style && !style.to_s.strip.empty?

      additions.any? ? ",\n              #{additions.join(",\n              ")}" : ""
    end

    # Le glossaire est un Hash ou une chaîne : String ne répond pas à #any?
    def glossary_present?(glossary)
      return glossary.any? if glossary.is_a?(Hash)

      !glossary.to_s.strip.empty?
    end

    def log_prompt_generation(prompt_type, source_locale, target_locale)
      message = "Generated #{prompt_type} prompt for #{source_locale} -> #{target_locale}"
      Logger.debug_if_verbose(message, sensitive: false)
    end
  end
end

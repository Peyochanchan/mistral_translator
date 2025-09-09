# frozen_string_literal: true

require_relative "logger"

module MistralTranslator
  module PromptMetadataHelpers
    def build_metadata_additions(context, glossary, preserve_html)
      additions = []

      additions << '"has_context": true' if context && !context.to_s.strip.empty?
      additions << '"has_glossary": true' if glossary && !glossary.to_s.strip.empty? && glossary.any?
      additions << '"preserve_html": true' if preserve_html

      additions.any? ? ",\n              #{additions.join(",\n              ")}" : ""
    end

    def build_summary_metadata_additions(context, style)
      additions = []

      additions << '"has_context": true' if context && !context.to_s.strip.empty?
      additions << %("style": "#{style}") if style && !style.to_s.strip.empty?

      additions.any? ? ",\n              #{additions.join(",\n              ")}" : ""
    end

    def log_prompt_generation(prompt_type, source_locale, target_locale)
      message = "Generated #{prompt_type} prompt for #{source_locale} -> #{target_locale}"
      Logger.debug_if_verbose(message, sensitive: false)
    end

    def log_prompt_debug(_prompt)
      return unless ENV["MISTRAL_TRANSLATOR_DEBUG"]

      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.info message
      elsif ENV["MISTRAL_TRANSLATOR_DEBUG"]
        # Log de debug seulement si mode verbose activé
        Logger.debug_if_verbose(message, sensitive: false)
      end
    end
  end
end

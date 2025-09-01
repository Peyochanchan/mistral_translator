# frozen_string_literal: true

require_relative "mistral_translator/version"
require_relative "mistral_translator/errors"
require_relative "mistral_translator/configuration"
require_relative "mistral_translator/locale_helper"
require_relative "mistral_translator/prompt_builder"
require_relative "mistral_translator/response_parser"
require_relative "mistral_translator/client"
require_relative "mistral_translator/translator"
require_relative "mistral_translator/summarizer"

module MistralTranslator
  class << self
    # Méthodes de convenance pour accès direct
    def translate(text, from:, to:)
      translator.translate(text, from: from, to: to)
    end

    def translate_to_multiple(text, from:, to:)
      translator.translate_to_multiple(text, from: from, to: to)
    end

    def translate_batch(texts, from:, to:)
      translator.translate_batch(texts, from: from, to: to)
    end

    def translate_auto(text, to:)
      translator.translate_auto(text, to: to)
    end

    def summarize(text, language: "fr", max_words: 250)
      summarizer.summarize(text, language: language, max_words: max_words)
    end

    def summarize_and_translate(text, from:, to:, max_words: 250)
      summarizer.summarize_and_translate(text, from: from, to: to, max_words: max_words)
    end

    def summarize_to_multiple(text, languages:, max_words: 250)
      summarizer.summarize_to_multiple(text, languages: languages, max_words: max_words)
    end

    def summarize_tiered(text, language: "fr", short: 50, medium: 150, long: 300)
      summarizer.summarize_tiered(text, language: language, short: short, medium: medium, long: long)
    end

    # Méthodes utilitaires
    def supported_languages
      LocaleHelper.supported_languages_list
    end

    def supported_locales
      LocaleHelper.supported_locales
    end

    def locale_supported?(locale)
      LocaleHelper.locale_supported?(locale)
    end

    # Configuration
    def configure
      yield(configuration) if block_given?
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = Configuration.new
      @translator = nil
      @summarizer = nil
      @client = nil
    end

    # Version info
    def version
      VERSION
    end

    # Health check
    def health_check
      client.complete("Hello", max_tokens: 10)
      { status: :ok, message: "API connection successful" }
    rescue AuthenticationError
      { status: :error, message: "Authentication failed - check your API key" }
    rescue ApiError => e
      { status: :error, message: "API error: #{e.message}" }
    rescue StandardError => e
      { status: :error, message: "Unexpected error: #{e.message}" }
    end

    private

    def translator
      @translator ||= Translator.new(client: client)
    end

    def summarizer
      @summarizer ||= Summarizer.new(client: client)
    end

    def client
      @client ||= Client.new
    end
  end

  # Alias pour compatibilité
  module Convenience
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def mistral_translate(text, from:, to:)
        MistralTranslator.translate(text, from: from, to: to)
      end

      def mistral_summarize(text, language: "fr", max_words: 250)
        MistralTranslator.summarize(text, language: language, max_words: max_words)
      end
    end
  end
end

# Extensions optionnelles pour String
if ENV["MISTRAL_TRANSLATOR_EXTEND_STRING"]
  class String
    def mistral_translate(from:, to:)
      MistralTranslator.translate(self, from: from, to: to)
    end

    def mistral_summarize(language: "fr", max_words: 250)
      MistralTranslator.summarize(self, language: language, max_words: max_words)
    end
  end
end

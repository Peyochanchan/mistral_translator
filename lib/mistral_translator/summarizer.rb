# frozen_string_literal: true

require_relative "logger"
require_relative "retries"
require_relative "security"

module MistralTranslator
  class Summarizer
    include Retries

    DEFAULT_MAX_WORDS = 250
    DEFAULT_RETRY_COUNT = Retries::RETRY_COUNT
    DEFAULT_RETRY_DELAY = Retries::RETRY_DELAY

    def initialize(client: nil)
      @client = client || Client.new
      log_debug("Summarizer initialized")
    end

    # Résumé simple dans une langue donnée
    def summarize(text, language: "fr", max_words: DEFAULT_MAX_WORDS, context: nil, style: nil)
      log_debug("Starting summarize - language: #{language}, max_words: #{max_words}")

      # Validation basique des entrées
      validated_text = Security::BasicValidator.validate_text!(text)
      raise ArgumentError, "Max words must be positive" unless max_words.is_a?(Integer) && max_words.positive?

      # Si le texte est vide, retourner directement une chaîne vide
      return "" if validated_text.empty?

      target_locale = LocaleHelper.validate_locale!(language)
      cleaned_text = clean_document_content(validated_text)

      prompt = PromptBuilder.summary_prompt(cleaned_text, max_words, target_locale, context: context, style: style)
      request_summary(prompt, target_locale)
    end

    # Résumé avec traduction simultanée
    def summarize_and_translate(text, from:, to:, max_words: DEFAULT_MAX_WORDS, context: nil, style: nil) # rubocop:disable Metrics/ParameterLists
      log_debug("Starting summarize_and_translate - from: #{from}, to: #{to}")
      validate_summarize_translate_inputs!(text, from, to, max_words)

      source_locale = LocaleHelper.validate_locale!(from)
      target_locale = LocaleHelper.validate_locale!(to)
      cleaned_text = clean_document_content(text)

      # Si même langue, juste résumer
      if source_locale == target_locale
        return summarize(cleaned_text, language: target_locale, max_words: max_words, context: context, style: style)
      end

      prompt = PromptBuilder.summary_and_translation_prompt(cleaned_text, source_locale, target_locale, max_words,
                                                            context: context, style: style)
      request_summary(prompt, target_locale)
    end

    # Résumé en plusieurs langues
    def summarize_to_multiple(text, languages:, max_words: DEFAULT_MAX_WORDS, context: nil, style: nil)
      log_debug("Starting summarize_to_multiple - languages: #{languages}")
      validate_multiple_summarize_inputs!(text, languages, max_words)

      target_locales = Array(languages).map { |locale| LocaleHelper.validate_locale!(locale) }
      cleaned_text = clean_document_content(text)

      target_locales.each_with_index.to_h do |target_locale, index|
        # Ajouter un délai seulement entre les requêtes (pas avant la première)
        sleep(DEFAULT_RETRY_DELAY) if index.positive?

        prompt = PromptBuilder.summary_prompt(cleaned_text, max_words, target_locale, context: context, style: style)
        [target_locale, request_summary(prompt, target_locale)]
      end
    end

    # Résumé par niveaux (court, moyen, long)
    def summarize_tiered(text, language: "fr", short: 50, medium: 150, long: 300, context: nil, style: nil) # rubocop:disable Metrics/ParameterLists
      log_debug("Starting summarize_tiered - short: #{short}, medium: #{medium}, long: #{long}")
      validate_tiered_inputs!(text, language, short, medium, long)

      target_locale = LocaleHelper.validate_locale!(language)
      cleaned_text = clean_document_content(text)

      { short: short, medium: medium, long: long }.transform_values do |max_words|
        prompt = PromptBuilder.summary_prompt(cleaned_text, max_words, target_locale, context: context, style: style)
        request_summary(prompt, target_locale)
      end
    end

    private

    # Commun à tous les résumés ; une réponse inexploitable finit par lever une erreur.
    def request_summary(prompt, target_locale)
      with_retries(operation: "summary", subject: target_locale) do |attempt|
        log_debug("Summary attempt #{attempt + 1} for #{target_locale}")

        result = ResponseParser.parse_summary_response(@client.complete(prompt, json: true))
        raise EmptyTranslationError, "Empty summary received" if result.nil? || result[:summary].to_s.empty?

        result[:summary]
      end
    end

    def clean_document_content(content)
      return content if content.nil?

      log_debug("Cleaning document content - original length: #{content.length}")

      result = content
               # Étape 1: Normaliser tous les espaces/tabs en espaces simples
               .gsub(/[ \t]+/, " ")
               # Étape 2: Supprimer les séparateurs de ligne (---, ----, etc.)
               .gsub(/-{3,}/, "")
               # Étape 3: Supprimer les lignes vides multiples (y compris celles avec espaces)
               .gsub(/\n\s*\n+/, "\n")
               # Étape 4: Supprimer espaces en début/fin de ligne
               .gsub(/^[ \t]+|[ \t]+$/m, "")
               # Étape 5: Nettoyer les espaces multiples créés par les suppressions précédentes
               .gsub(/[ \t]+/, " ")
               # Étape 6: Nettoyer le début et la fin
               .strip

      log_debug("Text cleaned - new length: #{result.length}")
      result
    end

    def validate_summarize_inputs!(text, language, max_words)
      raise ArgumentError, "Text cannot be nil or empty" if text.nil? || text.empty?

      Security::BasicValidator.validate_text!(text)
      raise ArgumentError, "Language cannot be nil" if language.nil?
      raise ArgumentError, "Max words must be a positive integer" unless max_words.is_a?(Integer) && max_words.positive?
    end

    def validate_summarize_translate_inputs!(text, from, to, max_words)
      validate_summarize_inputs!(text, to, max_words)
      raise ArgumentError, "Source language cannot be nil" if from.nil?
    end

    def validate_multiple_summarize_inputs!(text, languages, max_words)
      languages_array = Array(languages)
      first_language = languages_array.first || "fr"
      validate_summarize_inputs!(text, first_language, max_words)
      raise ArgumentError, "Languages array cannot be empty" if languages_array.empty?
    end

    def validate_tiered_inputs!(text, language, short, medium, long)
      validate_summarize_inputs!(text, language, short)
      raise ArgumentError, "Medium length must be greater than short" unless medium > short
      raise ArgumentError, "Long length must be greater than medium" unless long > medium
    end

    def log_debug(message)
      Logger.debug_if_verbose(message, sensitive: false)
    end
  end
end

# frozen_string_literal: true

require_relative "logger"

module MistralTranslator
  class Summarizer
    DEFAULT_MAX_WORDS = 250
    DEFAULT_RETRY_COUNT = 3
    DEFAULT_RETRY_DELAY = 2

    def initialize(client: nil)
      @client = client || Client.new
      log_debug("Summarizer initialized")
    end

    # Résumé simple dans une langue donnée
    def summarize(text, language: "fr", max_words: DEFAULT_MAX_WORDS)
      log_debug("Starting summarize - language: #{language}, max_words: #{max_words}")
      validate_summarize_inputs!(text, language, max_words)

      target_locale = LocaleHelper.validate_locale!(language)
      log_debug("Target locale validated: #{target_locale}")

      cleaned_text = clean_document_content(text)
      log_debug("Text cleaned, length: #{cleaned_text&.length}")

      result = summarize_with_retry(cleaned_text, target_locale, max_words)
      log_debug("Summary completed successfully")
      result
    end

    # Résumé avec traduction simultanée
    def summarize_and_translate(text, from:, to:, max_words: DEFAULT_MAX_WORDS)
      log_debug("Starting summarize_and_translate - from: #{from}, to: #{to}")
      validate_summarize_translate_inputs!(text, from, to, max_words)

      source_locale = LocaleHelper.validate_locale!(from)
      target_locale = LocaleHelper.validate_locale!(to)
      cleaned_text = clean_document_content(text)

      # Si même langue, juste résumer
      if source_locale == target_locale
        log_debug("Same language detected, using simple summarize")
        return summarize(cleaned_text, language: target_locale, max_words: max_words)
      end

      # Sinon, créer un prompt qui fait les deux à la fois
      log_debug("Different languages, using combined summarize+translate")
      prompt = build_summary_translation_prompt(cleaned_text, source_locale, target_locale, max_words)
      raw_response = @client.complete(prompt)

      result = ResponseParser.parse_summary_response(raw_response)
      if result.nil? || result[:summary].nil? || result[:summary].empty?
        raise EmptyTranslationError, "Empty summary received from summarize_and_translate"
      end

      result[:summary]
    end

    # Résumé en plusieurs langues
    def summarize_to_multiple(text, languages:, max_words: DEFAULT_MAX_WORDS)
      log_debug("Starting summarize_to_multiple - languages: #{languages}")
      validate_multiple_summarize_inputs!(text, languages, max_words)

      target_locales = Array(languages).map { |locale| LocaleHelper.validate_locale!(locale) }
      cleaned_text = clean_document_content(text)
      results = {}

      target_locales.each_with_index do |target_locale, index|
        log_debug("Processing language #{index + 1}/#{target_locales.length}: #{target_locale}")

        # Ajouter un délai seulement entre les requêtes (pas avant la première)
        if index.positive?
          log_debug("Adding delay between requests: #{DEFAULT_RETRY_DELAY}s")
          sleep(DEFAULT_RETRY_DELAY)
        end

        results[target_locale] = summarize_with_retry(cleaned_text, target_locale, max_words)
      end

      log_debug("Multiple summarization completed")
      results
    end

    # Résumé par niveaux (court, moyen, long)
    def summarize_tiered(text, language: "fr", short: 50, medium: 150, long: 300)
      log_debug("Starting summarize_tiered - short: #{short}, medium: #{medium}, long: #{long}")
      validate_tiered_inputs!(text, language, short, medium, long)

      target_locale = LocaleHelper.validate_locale!(language)
      cleaned_text = clean_document_content(text)

      {
        short: summarize_with_retry(cleaned_text, target_locale, short),
        medium: summarize_with_retry(cleaned_text, target_locale, medium),
        long: summarize_with_retry(cleaned_text, target_locale, long)
      }
    end

    private

    def summarize_with_retry(text, target_locale, max_words, attempt = 0)
      log_debug("Summarize attempt #{attempt + 1} for #{target_locale}")

      prompt = PromptBuilder.summary_prompt(text, max_words, target_locale)
      raw_response = @client.complete(prompt)

      result = ResponseParser.parse_summary_response(raw_response)
      if result.nil? || result[:summary].nil? || result[:summary].empty?
        raise EmptyTranslationError, "Empty summary received"
      end

      log_debug("Summary successful for #{target_locale}")
      result[:summary]
    rescue EmptyTranslationError, InvalidResponseError => e
      if attempt < DEFAULT_RETRY_COUNT
        wait_time = DEFAULT_RETRY_DELAY * (2**attempt)
        log_retry(e, attempt + 1, wait_time, target_locale)
        sleep(wait_time)
        summarize_with_retry(text, target_locale, max_words, attempt + 1)
      else
        log_debug("Max retries reached for #{target_locale}, giving up")
        raise e
      end
    rescue RateLimitError => e
      log_rate_limit_hit("summary", target_locale)
      sleep(DEFAULT_RETRY_DELAY)
      retry
    end

    def build_summary_translation_prompt(text, source_locale, target_locale, max_words)
      source_name = LocaleHelper.locale_to_language(source_locale)
      target_name = LocaleHelper.locale_to_language(target_locale)

      <<~PROMPT
        Tu es un assistant spécialisé dans la création de résumés et traductions simultanées.#{" "}
        Résume ET traduis le texte suivant en respectant ces règles strictes :
        1. Langue source : #{source_name} (#{source_locale})
        2. Langue cible : #{target_name} (#{target_locale})
        3. Longueur maximale : #{max_words} mots
        4. Créer un résumé du texte ET le traduire vers la langue cible
        5. Format de réponse obligatoire en JSON :
        {
          "content": {
            "source": "texte original",
            "target": "résumé traduit en #{target_name}"
          },
          "metadata": {
            "source_language": "#{source_locale}",
            "target_language": "#{target_locale}",
            "max_words": #{max_words},
            "operation": "summarize_and_translate"
          }
        }

        Texte à résumer et traduire :
        #{text}
      PROMPT
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

    def log_retry(error, attempt, wait_time, locale)
      message = "Summary retry #{attempt}/#{DEFAULT_RETRY_COUNT} for #{locale} in #{wait_time}s: #{error.message}"
      # Log une seule fois par locale et type d'erreur
      Logger.warn_once(message, key: "summary_retry_#{locale}_#{error.class.name}", sensitive: false, ttl: 120)
    end

    def log_rate_limit_hit(operation, locale)
      message = "Rate limit hit for #{operation} in #{locale}, retrying..."
      # Log une seule fois par opération et locale
      Logger.warn_once(message, key: "summary_rate_limit_#{operation}_#{locale}", sensitive: false, ttl: 300)
    end

    def log_debug(message)
      # Log de debug seulement si mode verbose activé
      Logger.debug_if_verbose(message, sensitive: false)

      # Pour les tests, permettre un output dans stdout si nécessaire
      return unless ENV["MISTRAL_TRANSLATOR_TEST_OUTPUT"] == "true"

      puts "[MistralTranslator] #{message}"
    end
  end
end

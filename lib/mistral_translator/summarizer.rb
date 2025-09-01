# frozen_string_literal: true

module MistralTranslator
  class Summarizer
    DEFAULT_MAX_WORDS = 250
    DEFAULT_RETRY_COUNT = 3
    DEFAULT_RETRY_DELAY = 2

    def initialize(client: nil)
      @client = client || Client.new
    end

    # Résumé simple dans une langue donnée
    def summarize(text, language: "fr", max_words: DEFAULT_MAX_WORDS)
      validate_summarize_inputs!(text, language, max_words)

      target_locale = LocaleHelper.validate_locale!(language)
      cleaned_text = clean_document_content(text)

      summarize_with_retry(cleaned_text, target_locale, max_words)
    end

    # Résumé avec traduction simultanée
    def summarize_and_translate(text, from:, to:, max_words: DEFAULT_MAX_WORDS)
      validate_summarize_translate_inputs!(text, from, to, max_words)

      source_locale = LocaleHelper.validate_locale!(from)
      target_locale = LocaleHelper.validate_locale!(to)
      cleaned_text = clean_document_content(text)

      # Si même langue, juste résumer
      return summarize(cleaned_text, language: target_locale, max_words: max_words) if source_locale == target_locale

      # Sinon, créer un prompt qui fait les deux à la fois
      prompt = build_summary_translation_prompt(cleaned_text, source_locale, target_locale, max_words)
      raw_response = @client.complete(prompt)

      result = ResponseParser.parse_summary_response(raw_response)
      result[:summary]
    end

    # Résumé en plusieurs langues
    def summarize_to_multiple(text, languages:, max_words: DEFAULT_MAX_WORDS)
      validate_multiple_summarize_inputs!(text, languages, max_words)

      target_locales = Array(languages).map { |locale| LocaleHelper.validate_locale!(locale) }
      cleaned_text = clean_document_content(text)
      results = {}

      target_locales.each do |target_locale|
        sleep(DEFAULT_RETRY_DELAY) # Délai entre les requêtes
        results[target_locale] = summarize_with_retry(cleaned_text, target_locale, max_words)
      end

      results
    end

    # Résumé par niveaux (court, moyen, long)
    def summarize_tiered(text, language: "fr", short: 50, medium: 150, long: 300)
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
      prompt = PromptBuilder.summary_prompt(text, max_words, target_locale)
      raw_response = @client.complete(prompt)

      result = ResponseParser.parse_summary_response(raw_response)
      raise EmptyTranslationError, "Empty summary received" if result.nil? || result[:summary].nil?

      result[:summary]
    rescue EmptyTranslationError, InvalidResponseError => e
      raise e unless attempt < DEFAULT_RETRY_COUNT

      wait_time = DEFAULT_RETRY_DELAY * (2**attempt)
      log_retry(e, attempt + 1, wait_time, target_locale)
      sleep(wait_time)
      summarize_with_retry(text, target_locale, max_words, attempt + 1)
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

      content
        .gsub(/\s{2,}/, " ")                    # Remplace les espaces multiples par un seul
        .gsub(/\n\s*\n/, "\n")                  # Supprime les lignes vides
        .gsub(/-{3,}/, "") # Supprime les lignes de séparation
        .gsub(/^\s+/, "")                       # Supprime les espaces en début de ligne
        .gsub(/\s+$/, "")                       # Supprime les espaces en fin de ligne
        .gsub(/\n+/, "\n")                      # Remplace les retours à la ligne multiples
        .strip
    end

    def validate_summarize_inputs!(text, language, max_words)
      raise ArgumentError, "Text cannot be nil or empty" if text.nil? || text.empty?
      raise ArgumentError, "Language cannot be nil" if language.nil?
      raise ArgumentError, "Max words must be a positive integer" unless max_words.is_a?(Integer) && max_words > 0
    end

    def validate_summarize_translate_inputs!(text, from, to, max_words)
      validate_summarize_inputs!(text, to, max_words)
      raise ArgumentError, "Source language cannot be nil" if from.nil?
    end

    def validate_multiple_summarize_inputs!(text, languages, max_words)
      validate_summarize_inputs!(text, languages.first || "fr", max_words)
      raise ArgumentError, "Languages array cannot be empty" if Array(languages).empty?
    end

    def validate_tiered_inputs!(text, language, short, medium, long)
      validate_summarize_inputs!(text, language, short)
      raise ArgumentError, "Medium length must be greater than short" unless medium > short
      raise ArgumentError, "Long length must be greater than medium" unless long > medium
    end

    def validate_translation_inputs!(text, from, to)
      raise ArgumentError, "Text cannot be nil or empty" if text.nil? || text.empty?
      raise ArgumentError, "Source language cannot be nil" if from.nil?
      raise ArgumentError, "Target languages cannot be empty" if Array(to).empty?
    end

    def validate_batch_inputs!(texts, from, to)
      raise ArgumentError, "Texts array cannot be nil or empty" if texts.nil? || texts.empty?
      raise ArgumentError, "Source language cannot be nil" if from.nil?
      raise ArgumentError, "Target language cannot be nil" if to.nil?

      texts.each_with_index do |text, index|
        raise ArgumentError, "Text at index #{index} cannot be nil or empty" if text.nil? || text.empty?
      end
    end

    def log_retry(error, attempt, wait_time, locale)
      message = "[MistralTranslator] Summary retry #{attempt}/#{DEFAULT_RETRY_COUNT} for #{locale} in #{wait_time}s: #{error.message}"

      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.warn message
      elsif ENV["MISTRAL_TRANSLATOR_DEBUG"]
        puts message
      end
    end

    def log_rate_limit_hit(operation, locale)
      message = "[MistralTranslator] Rate limit hit for #{operation} in #{locale}, retrying..."

      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.warn message
      elsif ENV["MISTRAL_TRANSLATOR_DEBUG"]
        puts message
      end
    end
  end
end

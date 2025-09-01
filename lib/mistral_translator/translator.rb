# frozen_string_literal: true

module MistralTranslator
  class Translator
    DEFAULT_RETRY_COUNT = 3
    DEFAULT_RETRY_DELAY = 2

    def initialize(client: nil)
      @client = client || Client.new
    end

    # Traduction simple d'un texte vers une langue
    def translate(text, from:, to:)
      validate_inputs!(text, from, to)

      source_locale = LocaleHelper.validate_locale!(from)
      target_locale = LocaleHelper.validate_locale!(to)

      translate_with_retry(text, source_locale, target_locale)
    end

    # Traduction vers plusieurs langues
    def translate_to_multiple(text, from:, to:)
      validate_translation_inputs!(text, from, to)

      source_locale = LocaleHelper.validate_locale!(from)
      target_locales = Array(to).map { |locale| LocaleHelper.validate_locale!(locale) }

      results = {}

      target_locales.each_with_index do |target_locale, index|
        # Délai entre les requêtes, mais pas avant la première
        sleep(DEFAULT_RETRY_DELAY) if index > 0
        results[target_locale] = translate_with_retry(text, source_locale, target_locale)
      end

      results
    end

    # Traduction en lot (plusieurs textes vers une langue)
    def translate_batch(texts, from:, to:)
      validate_batch_inputs!(texts, from, to)

      source_locale = LocaleHelper.validate_locale!(from)
      target_locale = LocaleHelper.validate_locale!(to)

      # Pour des lots importants, on peut les découper
      if texts.length > 10
        translate_large_batch(texts, source_locale, target_locale)
      else
        translate_small_batch(texts, source_locale, target_locale)
      end
    end

    # Auto-détection de la langue source (utilise l'API pour détecter)
    def translate_auto(text, to:)
      target_locale = LocaleHelper.validate_locale!(to)

      # Premier appel pour détecter la langue
      detection_prompt = build_language_detection_prompt(text)
      detection_response = @client.complete(detection_prompt)
      detected_language = parse_language_detection(detection_response)

      # Puis traduction normale
      translate(text, from: detected_language, to: target_locale)
    end

    private

    def translate_with_retry(text, source_locale, target_locale, attempt = 0)
      prompt = PromptBuilder.translation_prompt(text, source_locale, target_locale)
      raw_response = @client.complete(prompt)

      result = ResponseParser.parse_translation_response(raw_response)
      raise EmptyTranslationError if result.nil? || result[:translated].nil?

      result[:translated]
    rescue EmptyTranslationError, InvalidResponseError => e
      raise e unless attempt < DEFAULT_RETRY_COUNT

      wait_time = DEFAULT_RETRY_DELAY * (2**attempt) # Backoff exponentiel
      log_retry(e, attempt + 1, wait_time)
      sleep(wait_time)
      translate_with_retry(text, source_locale, target_locale, attempt + 1)
    rescue RateLimitError => e
      log_rate_limit_hit(source_locale, target_locale)
      sleep(DEFAULT_RETRY_DELAY)
      retry
    end

    def translate_small_batch(texts, source_locale, target_locale)
      prompt = PromptBuilder.bulk_translation_prompt(texts, source_locale, target_locale)
      raw_response = @client.complete(prompt)

      results = ResponseParser.parse_bulk_translation_response(raw_response)

      # Retourner un hash indexé par l'ordre original
      results.each_with_object({}) do |result, hash|
        original_index = result[:index] - 1 # L'API retourne 1-indexed
        hash[original_index] = result[:translated]
      end
    end

    def translate_large_batch(texts, source_locale, target_locale)
      results = {}

      texts.each_slice(10).with_index do |batch, batch_index|
        sleep(DEFAULT_RETRY_DELAY) if batch_index > 0 # Délai entre les batches

        batch_results = translate_small_batch(batch, source_locale, target_locale)

        # Ajuster les index pour le batch
        batch_results.each do |local_index, translation|
          global_index = (batch_index * 10) + local_index
          results[global_index] = translation
        end
      end

      results
    end

    def build_language_detection_prompt(text)
      <<~PROMPT
        Détecte la langue du texte suivant et réponds uniquement avec le code ISO 639-1 de la langue (ex: 'fr', 'en', 'es').

        Format de réponse obligatoire en JSON :
        {
          "detected_language": "code_iso"
        }

        Texte à analyser :
        #{text}
      PROMPT
    end

    def parse_language_detection(response)
      json_content = response.match(/\{.*\}/m)&.[](0)
      return "en" unless json_content # Défaut en anglais si détection échoue

      data = JSON.parse(json_content)
      detected = data["detected_language"]

      LocaleHelper.locale_supported?(detected) ? detected : "en"
    rescue JSON::ParserError
      "en" # Défaut en anglais si parsing échoue
    end

    def validate_inputs!(text, from, to)
      raise ArgumentError, "Text cannot be nil or empty" if text.nil? || text.empty?
      raise ArgumentError, "Source language cannot be nil" if from.nil?
      raise ArgumentError, "Target language cannot be nil" if to.nil?
      raise ArgumentError, "Source and target languages cannot be the same" if from == to
    end

    def validate_translation_inputs!(text, from, to)
      # Convertir to en array pour la validation
      target_languages = Array(to)
      raise ArgumentError, "Target languages cannot be empty" if target_languages.empty?
      validate_inputs!(text, from, target_languages.first)
    end

    def validate_batch_inputs!(texts, from, to)
      raise ArgumentError, "Texts array cannot be nil or empty" if texts.nil? || texts.empty?
      raise ArgumentError, "Source language cannot be nil" if from.nil?
      raise ArgumentError, "Target language cannot be nil" if to.nil?

      texts.each_with_index do |text, index|
        raise ArgumentError, "Text at index #{index} cannot be nil or empty" if text.nil? || text.empty?
      end
    end

    def log_retry(error, attempt, wait_time)
      message = "[MistralTranslator] #{error.class.name}: #{error.message}. Retry #{attempt}/#{DEFAULT_RETRY_COUNT} in #{wait_time}s"

      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.warn message
      elsif ENV["MISTRAL_TRANSLATOR_DEBUG"]
        puts message
      end
    end

    def log_rate_limit_hit(source, target)
      message = "[MistralTranslator] Rate limit hit for translation #{source} -> #{target}, retrying..."

      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.warn message
      elsif ENV["MISTRAL_TRANSLATOR_DEBUG"]
        puts message
      end
    end
  end
end

# frozen_string_literal: true

require_relative "logger"

module MistralTranslator
  class Translator
    DEFAULT_RETRY_COUNT = 3
    DEFAULT_RETRY_DELAY = 2

    def initialize(client: nil)
      @client = client || Client.new
    end

    # Traduction simple d'un texte vers une langue
    def translate(text, from:, to:, context: nil, glossary: nil, preserve_html: false)
      validate_inputs!(text, from, to)

      source_locale = LocaleHelper.validate_locale!(from)
      target_locale = LocaleHelper.validate_locale!(to)

      translate_with_retry(text, source_locale, target_locale, context: context, glossary: glossary,
                                                               preserve_html: preserve_html)
    end

    # Traduction avec score de confiance (expérimental)
    def translate_with_confidence(text, from:, to:, context: nil, glossary: nil)
      result = translate(text, from: from, to: to, context: context, glossary: glossary)

      # Score de confiance basique basé sur la longueur et la cohérence
      confidence = calculate_confidence_score(text, result, from, to)

      {
        translation: result,
        confidence: confidence,
        metadata: {
          source_locale: from,
          target_locale: to,
          original_length: text.length,
          translated_length: result.length
        }
      }
    end

    # Traduction vers plusieurs langues avec support du batch
    def translate_to_multiple(text, from:, to:, context: nil, glossary: nil, use_batch: false)
      validate_translation_inputs!(text, from, to)

      source_locale = LocaleHelper.validate_locale!(from)
      target_locales = Array(to).map { |locale| LocaleHelper.validate_locale!(locale) }

      if use_batch && target_locales.size > 3
        translate_to_multiple_batch(text, source_locale, target_locales, context: context, glossary: glossary)
      else
        translate_to_multiple_sequential(text, source_locale, target_locales, context: context, glossary: glossary)
      end
    end

    # Traduction en lot (plusieurs textes vers une langue)
    def translate_batch(texts, from:, to:, context: nil, glossary: nil)
      validate_batch_inputs!(texts, from, to)

      source_locale = LocaleHelper.validate_locale!(from)
      target_locale = LocaleHelper.validate_locale!(to)

      # Optimisation : utiliser le nouveau système de batch du client
      requests = texts.map.with_index do |text, index|
        {
          prompt: build_translation_prompt(text, source_locale, target_locale, context: context, glossary: glossary),
          from: source_locale,
          to: target_locale,
          index: index,
          original_text: text
        }
      end

      batch_results = @client.translate_batch(requests, batch_size: 10)

      # Traiter les résultats
      process_batch_results(batch_results, texts)
    end

    # Auto-détection de la langue source avec support du contexte
    def translate_auto(text, to:, context: nil, glossary: nil)
      target_locale = LocaleHelper.validate_locale!(to)

      # Premier appel pour détecter la langue
      detection_prompt = build_language_detection_prompt(text)
      detection_response = @client.complete(detection_prompt)
      detected_language = parse_language_detection(detection_response)

      # Vérifier que la langue détectée est différente de la cible
      if detected_language == target_locale
        # Si même langue, retourner le texte original
        return text
      end

      # Puis traduction normale avec contexte
      translate(text, from: detected_language, to: target_locale, context: context, glossary: glossary)
    end

    private

    def translate_to_multiple_batch(text, source_locale, target_locales, context: nil, glossary: nil)
      requests = target_locales.map do |target_locale|
        {
          prompt: build_translation_prompt(text, source_locale, target_locale, context: context, glossary: glossary),
          from: source_locale,
          to: target_locale,
          original_text: text
        }
      end

      batch_results = @client.translate_batch(requests, batch_size: 5)

      results = {}
      batch_results.each do |result|
        next unless result[:success]

        target_locale = result[:original_request][:to]
        parsed_result = ResponseParser.parse_translation_response(result[:result])
        results[target_locale] = parsed_result[:translated] if parsed_result
      end

      results
    end

    def translate_to_multiple_sequential(text, source_locale, target_locales, context: nil, glossary: nil)
      results = {}

      target_locales.each_with_index do |target_locale, index|
        # Délai entre les requêtes, mais pas avant la première
        sleep(DEFAULT_RETRY_DELAY) if index.positive?
        results[target_locale] =
          translate_with_retry(text, source_locale, target_locale, context: context, glossary: glossary)
      end

      results
    end

    def process_batch_results(batch_results, _original_texts)
      results = {}

      batch_results.each do |result|
        index = result[:original_request][:index]
        if result[:success]
          parsed_result = ResponseParser.parse_translation_response(result[:result])
          results[index] = parsed_result[:translated] if parsed_result
        else
          results[index] = nil # ou une valeur d'erreur
        end
      end

      results
    end

    def translate_with_retry(text, source_locale, target_locale, attempt = 0, context: nil, glossary: nil,
                             preserve_html: false)
      prompt = build_translation_prompt(text, source_locale, target_locale, context: context, glossary: glossary,
                                                                            preserve_html: preserve_html)

      request_context = {
        from_locale: source_locale,
        to_locale: target_locale,
        attempt: attempt
      }

      raw_response = @client.complete(prompt, context: request_context)

      result = ResponseParser.parse_translation_response(raw_response)
      raise EmptyTranslationError if result.nil? || result[:translated].nil?

      result[:translated]
    rescue EmptyTranslationError, InvalidResponseError => e
      raise e unless attempt < DEFAULT_RETRY_COUNT

      wait_time = DEFAULT_RETRY_DELAY * (2**attempt) # Backoff exponentiel
      log_retry(e, attempt + 1, wait_time)
      sleep(wait_time)
      translate_with_retry(text, source_locale, target_locale, attempt + 1, context: context, glossary: glossary,
                                                                            preserve_html: preserve_html)
    rescue RateLimitError => e
      log_rate_limit_hit(source_locale, target_locale)
      sleep(DEFAULT_RETRY_DELAY)
      retry
    end

    def build_translation_prompt(text, source_locale, target_locale, context: nil, glossary: nil, preserve_html: false)
      base_prompt = PromptBuilder.translation_prompt(text, source_locale, target_locale, preserve_html: preserve_html)

      # Enrichir le prompt avec le contexte et le glossaire
      if (context && !context.to_s.strip.empty?) || (glossary && !glossary.to_s.strip.empty?)
        enrich_prompt_with_context(base_prompt, context, glossary)
      else
        base_prompt
      end
    end

    def enrich_prompt_with_context(base_prompt, context, glossary)
      enrichments = []

      enrichments << "CONTEXTE : #{context}" if context && !context.to_s.strip.empty?

      if glossary && glossary.is_a?(Hash) && glossary.any?
        glossary_text = glossary.map { |key, value| "#{key} → #{value}" }.join(", ")
        enrichments << "GLOSSAIRE (à respecter strictement) : #{glossary_text}"
      end

      if enrichments.any?
        enriched_context = enrichments.join("\n")
        base_prompt.sub(
          "RÈGLES :",
          "#{enriched_context}\n\nRÈGLES :"
        )
      else
        base_prompt
      end
    end

    def calculate_confidence_score(original, translated, from_locale, to_locale)
      # Score de confiance basique (à améliorer avec des métriques plus sophistiquées)
      length_ratio = translated.length.to_f / original.length

      # Ratio de longueur "normal" selon les langues
      expected_ratios = {
        %w[fr en] => [0.8, 1.2],
        %w[en fr] => [1.0, 1.3],
        %w[es en] => [0.7, 1.1],
        %w[en es] => [1.0, 1.4]
      }

      expected_range = expected_ratios[[from_locale.to_s, to_locale.to_s]] || [0.5, 2.0]

      base_confidence = if length_ratio.between?(expected_range[0], expected_range[1])
                          # Longueur dans la plage attendue
                          0.8
                        else
                          # Longueur suspecte
                          0.6
                        end

      # Ajuster selon d'autres critères
      if translated.strip.empty?
        0.0
      elsif original.length < 10
        [base_confidence - 0.2, 0.1].max # Textes très courts moins fiables
      else
        [base_confidence, 0.95].min
      end
    end

    def build_language_detection_prompt(text)
      PromptBuilder.language_detection_prompt(text)
    end

    def parse_language_detection(response)
      json_content = response.match(/\{.*\}/m)&.[](0)
      return "en" unless json_content # Défaut en anglais si détection échoue

      data = JSON.parse(json_content)
      detected = data.dig("metadata", "detected_language")

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
      message = "#{error.class.name}: #{error.message}. Retry #{attempt}/#{DEFAULT_RETRY_COUNT} in #{wait_time}s"
      # Log une seule fois par type d'erreur pour éviter le spam
      Logger.warn_once(message, key: "retry_#{error.class.name}", sensitive: false, ttl: 120)
    end

    def log_rate_limit_hit(source, target)
      message = "Rate limit hit for translation #{source} -> #{target}, retrying..."
      # Log une seule fois par paire de langues
      Logger.warn_once(message, key: "rate_limit_#{source}_#{target}", sensitive: false, ttl: 300)
    end
  end
end

# frozen_string_literal: true

require_relative "logger"
require_relative "translator_helpers"
require_relative "security"

module MistralTranslator
  class Translator
    include TranslatorHelpers::InputValidator
    include TranslatorHelpers::RetryHandler
    include TranslatorHelpers::LoggingHelper
    include TranslatorHelpers::PromptHandler
    include TranslatorHelpers::AnalysisHelper
    include TranslatorHelpers::RequestHelper
    include TranslatorHelpers::MultiTargetHelper

    DEFAULT_RETRY_COUNT = 3
    DEFAULT_RETRY_DELAY = 2

    def initialize(client: nil)
      @client = client || Client.new
    end

    # Traduction simple d'un texte vers une langue
    def translate(text, from:, to:, **options)
      # Validation basique des entrées
      validated_text = Security::BasicValidator.validate_text!(text)

      # Si le texte est vide, retourner directement une chaîne vide
      return "" if validated_text.empty?

      source_locale = LocaleHelper.validate_locale!(from)
      target_locale = LocaleHelper.validate_locale!(to)

      # Si même langue source et cible, retourner le texte original
      return validated_text if source_locale == target_locale

      translate_with_retry(validated_text, source_locale, target_locale,
                           context: options[:context],
                           glossary: options[:glossary],
                           preserve_html: options.fetch(:preserve_html, false))
    end

    # Traduction avec score de confiance (expérimental)
    def translate_with_confidence(text, from:, to:, context: nil, glossary: nil)
      result = begin
        translate(text, from: from, to: to, context: context, glossary: glossary)
      rescue EmptyTranslationError
        ""
      end

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
    def translate_to_multiple(text, from:, to:, **options)
      validate_translation_inputs!(text, from, to)

      source_locale = LocaleHelper.validate_locale!(from)
      target_locales = Array(to).map { |locale| LocaleHelper.validate_locale!(locale) }

      if options[:use_batch] && target_locales.size > 3
        translate_to_multiple_batch(text, source_locale, target_locales, context: options[:context],
                                                                         glossary: options[:glossary])
      else
        translate_to_multiple_sequential(text, source_locale, target_locales, context: options[:context],
                                                                              glossary: options[:glossary])
      end
    end

    # Traduction en lot (plusieurs textes vers une langue)
    def translate_batch(texts, from:, to:, context: nil, glossary: nil)
      validated_texts = Security::BasicValidator.validate_batch!(texts)
      source_locale = LocaleHelper.validate_locale!(from)
      target_locale = LocaleHelper.validate_locale!(to)

      return handle_same_language_batch(validated_texts) if source_locale == target_locale

      process_mixed_batch(validated_texts, source_locale, target_locale, context, glossary)
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

    # Ces méthodes sont héritées via MultiTargetHelper

    def handle_same_language_batch(validated_texts)
      validated_texts.each_with_index.to_h { |text, index| [index, text] }
    end

    def process_mixed_batch(validated_texts, source_locale, target_locale, context, glossary)
      results = {}
      batch_config = { source_locale: source_locale, target_locale: target_locale, context: context,
                       glossary: glossary }
      requests = build_batch_requests(validated_texts, batch_config, results)

      process_batch_requests(requests, results) if requests.any?

      results
    end

    def build_batch_requests(validated_texts, batch_config, results)
      requests = []

      validated_texts.each_with_index do |text, index|
        if text.nil? || text.empty?
          results[index] = ""
        else
          requests << create_batch_request(text, batch_config, index)
        end
      end

      requests
    end

    def create_batch_request(text, batch_config, index)
      {
        prompt: build_translation_prompt(text, batch_config[:source_locale], batch_config[:target_locale],
                                         context: batch_config[:context], glossary: batch_config[:glossary]),
        from: batch_config[:source_locale],
        to: batch_config[:target_locale],
        index: index,
        original_text: text
      }
    end

    def process_batch_requests(requests, results)
      batch_results = @client.translate_batch(requests, batch_size: 10)
      batch_results.each do |result|
        process_batch_result(result, results)
      end
    end

    def process_batch_result(result, results)
      index = result[:original_request][:index]
      results[index] = (parse_batch_response(result[:result]) if result[:success])
    end

    def parse_batch_response(response)
      parsed_result = ResponseParser.parse_translation_response(response)
      parsed_result[:translated] if parsed_result
    rescue EmptyTranslationError
      ""
    end

    def translate_with_retry(text, source_locale, target_locale, attempt = 0, **options)
      prompt = build_prompt_for_retry(text, source_locale, target_locale, **options)
      request_context = build_request_context(source_locale, target_locale, attempt)

      raw_response = perform_client_request(prompt, request_context)
      extract_translated_text!(raw_response)
    rescue EmptyTranslationError, InvalidResponseError => e
      handle_retryable_error!(e, attempt) do
        translate_with_retry(text, source_locale, target_locale, attempt + 1, **options)
      end
    rescue RateLimitError
      log_rate_limit_hit(source_locale, target_locale)
      sleep(DEFAULT_RETRY_DELAY)
      retry
    end

    # Ces méthodes sont héritées via RequestHelper

    # Log via LoggingHelper

    def build_translation_prompt(text, source_locale, target_locale, **options)
      base_prompt = PromptBuilder.translation_prompt(text, source_locale, target_locale,
                                                     preserve_html: options.fetch(:preserve_html, false))

      # Enrichir le prompt avec le contexte et le glossaire
      context_present = options[:context] && !options[:context].to_s.strip.empty?
      glossary_present =
        (options[:glossary].is_a?(Hash) && options[:glossary].any?) ||
        (options[:glossary].is_a?(String) && !options[:glossary].to_s.strip.empty?)
      if context_present || glossary_present
        enrich_prompt_with_context(base_prompt, options[:context], options[:glossary])
      else
        base_prompt
      end
    end

    def enrich_prompt_with_context(base_prompt, context, glossary)
      enriched_parts = []
      context_part = build_context_enrichment(context)
      glossary_part = build_glossary_enrichment(glossary)
      enriched_parts << context_part if context_part
      enriched_parts << glossary_part if glossary_part

      return base_prompt if enriched_parts.empty?

      enriched_context = enriched_parts.join("\n")
      base_prompt.sub("RÈGLES :", "#{enriched_context}\n\nRÈGLES :")
    end

    def build_context_enrichment(context)
      return nil if context.nil? || context.to_s.strip.empty?

      "CONTEXTE : #{context}"
    end

    def build_glossary_enrichment(glossary)
      return nil if glossary.nil?
      return build_glossary_hash(glossary) if glossary.is_a?(Hash)
      return build_glossary_string(glossary) if glossary.is_a?(String)

      nil
    end

    def build_glossary_hash(glossary_hash)
      return nil if glossary_hash.empty?

      glossary_text = glossary_hash.map { |key, value| "#{key} → #{value}" }.join(", ")
      "GLOSSAIRE (à respecter strictement) : #{glossary_text}"
    end

    def build_glossary_string(glossary_string)
      value = glossary_string.to_s.strip
      return nil if value.empty?

      "GLOSSAIRE : #{value}"
    end
  end
end

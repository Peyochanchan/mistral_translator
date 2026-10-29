# frozen_string_literal: true

require_relative "logger"
require_relative "retries"
require_relative "translator_helpers"
require_relative "security"

module MistralTranslator
  class Translator
    include Retries
    include TranslatorHelpers::InputValidator
    include TranslatorHelpers::AnalysisHelper
    include TranslatorHelpers::RequestHelper
    include TranslatorHelpers::MultiTargetHelper

    DEFAULT_RETRY_COUNT = Retries::RETRY_COUNT
    DEFAULT_RETRY_DELAY = Retries::RETRY_DELAY

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
      Security::BasicValidator.validate_text!(text)

      source_locale = LocaleHelper.validate_locale!(from)
      target_locales = Array(to).map { |locale| LocaleHelper.validate_locale!(locale) }

      translation_options = { context: options[:context], glossary: options[:glossary] }
      translation_options[:preserve_html] = true if options[:preserve_html]

      if options[:use_batch] && target_locales.size > 3
        translate_to_multiple_batch(text, source_locale, target_locales, **translation_options)
      else
        translate_to_multiple_sequential(text, source_locale, target_locales, **translation_options)
      end
    end

    # Traduction en lot (plusieurs textes vers une langue)
    def translate_batch(texts, from:, to:, context: nil, glossary: nil, preserve_html: false) # rubocop:disable Metrics/ParameterLists
      validated_texts = Security::BasicValidator.validate_batch!(texts)
      source_locale = LocaleHelper.validate_locale!(from)
      target_locale = LocaleHelper.validate_locale!(to)

      return handle_same_language_batch(validated_texts) if source_locale == target_locale

      batch_config = { source_locale: source_locale, target_locale: target_locale, context: context,
                       glossary: glossary, preserve_html: preserve_html }
      process_mixed_batch(validated_texts, batch_config)
    end

    # Auto-détection de la langue source avec support du contexte
    def translate_auto(text, to:, context: nil, glossary: nil, preserve_html: false)
      validated_text = Security::BasicValidator.validate_text!(text)
      return "" if validated_text.empty?

      target_locale = LocaleHelper.validate_locale!(to)

      # Premier appel pour détecter la langue ; un échec lève une erreur
      detection_response = @client.complete(build_language_detection_prompt(validated_text), json: true)
      detected_language = parse_language_detection(detection_response)
      return validated_text if detected_language == target_locale

      # Puis traduction normale avec contexte
      translate(validated_text, from: detected_language, to: target_locale, context: context, glossary: glossary,
                                preserve_html: preserve_html)
    end

    private

    # Ces méthodes sont héritées via MultiTargetHelper

    def handle_same_language_batch(validated_texts)
      validated_texts.each_with_index.to_h { |text, index| [index, text] }
    end

    def process_mixed_batch(validated_texts, batch_config)
      results = {}
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
                                         context: batch_config[:context], glossary: batch_config[:glossary],
                                         preserve_html: batch_config[:preserve_html]),
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
    rescue InvalidResponseError
      # Une réponse illisible fait échouer son élément, pas tout le lot
      nil
    end

    def translate_with_retry(text, source_locale, target_locale, **)
      prompt = build_translation_prompt(text, source_locale, target_locale, **)

      with_retries(operation: "translation", subject: "#{source_locale}->#{target_locale}") do |attempt|
        raw_response = perform_client_request(prompt, build_request_context(source_locale, target_locale, attempt))
        extract_translated_text!(raw_response)
      end
    end

    def build_translation_prompt(text, source_locale, target_locale, **options)
      PromptBuilder.translation_prompt(text, source_locale, target_locale,
                                       context: options[:context],
                                       glossary: options[:glossary],
                                       preserve_html: options.fetch(:preserve_html, false))
    end
  end
end

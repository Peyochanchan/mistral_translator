# frozen_string_literal: true

module MistralTranslator
  module TranslatorHelpers
    # Helper pour la validation des entrées
    module InputValidator
      def validate_inputs!(text, from, to)
        raise ArgumentError, "Text cannot be nil or empty" if text.nil? || text.to_s.strip.empty?
        raise ArgumentError, "Source language cannot be nil" if from.nil?
        raise ArgumentError, "Source language cannot be empty" if from.to_s.strip.empty?
        raise ArgumentError, "Target language cannot be nil or empty" if to.nil? || to.to_s.strip.empty?

        return unless from.to_s.strip.downcase == to.to_s.strip.downcase

        raise ArgumentError,
              "Source and target languages cannot be the same"
      end

      def validate_translation_inputs!(text, from, to)
        validate_inputs!(text, from, to)
        raise ArgumentError, "Target languages cannot be empty" if Array(to).empty?
      end
    end

    # Helper pour l'analyse et la détection de langue
    module AnalysisHelper
      def calculate_confidence_score(original, translated, from_locale, to_locale)
        length_ratio = translated.length.to_f / original.length

        expected_ratios = {
          %w[fr en] => [0.8, 1.2],
          %w[en fr] => [1.0, 1.3],
          %w[es en] => [0.7, 1.1],
          %w[en es] => [1.0, 1.4]
        }

        expected_range = expected_ratios[[from_locale.to_s, to_locale.to_s]] || [0.5, 2.0]

        base_confidence = if length_ratio.between?(expected_range[0], expected_range[1])
                            0.8
                          else
                            0.6
                          end

        if translated.strip.empty?
          0.0
        elsif original.length < 10
          [base_confidence - 0.2, 0.1].max
        else
          [base_confidence, 0.95].min
        end
      end

      def build_language_detection_prompt(text)
        PromptBuilder.language_detection_prompt(text)
      end

      # Fail-closed : une détection illisible ou une langue non supportée lève une erreur,
      # au lieu de supposer une langue et de renvoyer le texte non traduit.
      def parse_language_detection(response)
        data = JSON.parse(response.to_s)
        metadata = data["metadata"] if data.is_a?(Hash)
        detected = LocaleHelper.normalize_locale(metadata["detected_language"]) if metadata.is_a?(Hash)
        return detected if detected && LocaleHelper.locale_supported?(detected)

        raise InvalidResponseError.new("Language detection failed", response)
      rescue JSON::ParserError
        raise InvalidResponseError.new("Language detection failed", response), cause: nil
      end
    end

    # Helper pour requêtes client et retries
    module RequestHelper
      def build_request_context(source_locale, target_locale, attempt)
        {
          from_locale: source_locale,
          to_locale: target_locale,
          attempt: attempt
        }
      end

      def perform_client_request(prompt, request_context)
        @client.complete(prompt, context: request_context, json: true)
      end

      # Une réponse inexploitable lève une erreur : jamais de réponse brute enregistrée comme traduction.
      def extract_translated_text!(raw_response)
        result = ResponseParser.parse_translation_response(raw_response)
        return result[:translated] if result && !result[:translated].to_s.empty?

        raise EmptyTranslationError
      end
    end

    # Helper pour traductions multi-cibles
    module MultiTargetHelper
      DEFAULT_MULTI_TARGET_OPTIONS = { context: nil, glossary: nil }.freeze

      # options : context, glossary, preserve_html
      def translate_to_multiple_batch(text, source_locale, target_locales, **options)
        options = DEFAULT_MULTI_TARGET_OPTIONS.merge(options)
        requests = target_locales.map do |target_locale|
          {
            prompt: build_translation_prompt(text, source_locale, target_locale, **options),
            from: source_locale,
            to: target_locale,
            original_text: text
          }
        end

        batch_results = @client.translate_batch(requests, batch_size: 5)

        results = {}
        batch_results.each do |result|
          next unless result[:success]

          translated = parse_batch_translation(result[:result])
          results[result[:original_request][:to]] = translated if translated
        end

        results
      end

      # Une réponse illisible fait échouer sa langue, pas tout le lot
      def parse_batch_translation(response)
        ResponseParser.parse_translation_response(response)&.fetch(:translated)
      rescue EmptyTranslationError, InvalidResponseError
        nil
      end

      def translate_to_multiple_sequential(text, source_locale, target_locales, **options)
        options = DEFAULT_MULTI_TARGET_OPTIONS.merge(options)
        results = {}

        target_locales.each_with_index do |target_locale, index|
          sleep(MistralTranslator::Translator::DEFAULT_RETRY_DELAY) if index.positive?
          results[target_locale] =
            translate_with_retry(text, source_locale, target_locale, **options)
        end

        results
      end
    end
  end
end

# frozen_string_literal: true

require_relative "helpers_extensions"
require_relative "levenshtein_helpers"

module MistralTranslator
  module Helpers
    extend HelpersExtensions::TranslationHelpers
    extend HelpersExtensions::AnalysisHelpers
    extend HelpersExtensions::CostHelpers

    class << self
      # Helper pour traduction par batch avec gestion d'erreurs avancée
      def translate_batch_with_fallback(texts, from:, to:, **options)
        # Fallback par défaut: retraduire individuellement les éléments manquants
        options = { fallback_strategy: :individual }.merge(options)
        translator = Translator.new

        begin
          results = attempt_batch_translation(translator, texts, from, to, options)
          handle_missing_results({ translator: translator, texts: texts, from: from, to: to, results: results },
                                 **options)
          results
        rescue StandardError => e
          handle_batch_failure(e, { translator: translator, texts: texts, from: from, to: to }, **options)
        end
      end

      private

      def attempt_batch_translation(translator, texts, from, to, options)
        translator.translate_batch(texts, from: from, to: to, context: options[:context], glossary: options[:glossary])
      end

      def handle_missing_results(translation_data, **options)
        translator = translation_data[:translator]
        texts = translation_data[:texts]
        from = translation_data[:from]
        to = translation_data[:to]
        results = translation_data[:results]

        missing_indices = find_missing_indices(texts, results)
        return unless missing_indices.any? && options[:fallback_strategy] == :individual

        translation_params = { translator: translator, texts: texts, from: from, to: to, results: results,
                               missing_indices: missing_indices }
        retry_missing_translations(translation_params, **options)
      end

      def find_missing_indices(texts, results)
        missing_indices = []
        texts.each_with_index do |_, index|
          missing_indices << index unless results[index]
        end
        missing_indices
      end

      def retry_missing_translations(params, **options)
        translator = params[:translator]
        texts = params[:texts]
        from = params[:from]
        to = params[:to]
        results = params[:results]
        missing_indices = params[:missing_indices]

        missing_indices.each do |index|
          results[index] =
            translator.translate(texts[index], from: from, to: to, context: options[:context],
                                               glossary: options[:glossary])
        rescue StandardError => e
          results[index] = { error: e.message }
        end
      end

      def handle_batch_failure(error, translation_data, **options)
        raise error unless options[:fallback_strategy] == :individual

        _translator = translation_data[:translator]
        texts = translation_data[:texts]
        from = translation_data[:from]
        to = translation_data[:to]

        translate_individually_with_errors(texts, from: from, to: to, context: options[:context],
                                                  glossary: options[:glossary])
      end

      # Helper pour traduction progressive avec callback
      public

      def translate_with_progress(items, from:, to:, context: nil, glossary: nil, &progress_callback)
        results = {}
        total = items.size

        items.each_with_index do |(key, text), index|
          begin
            result = MistralTranslator.translate(text, from: from, to: to, context: context, glossary: glossary)
            results[key] = { success: true, translation: result }
          rescue StandardError => e
            results[key] = { success: false, error: e.message }
          end

          # Appeler le callback de progression
          progress_callback&.call(index + 1, total, key, results[key])
        end

        results
      end

      # Helper pour résumé intelligent avec détection automatique
      def smart_summarize(text, max_words: 250, target_language: "fr", style: nil, context: nil)
        # Détecter si c'est du HTML/Rich Text
        is_html = text.include?("<") && text.include?(">")

        # Nettoyer pour l'analyse si nécessaire
        analysis_text = is_html ? strip_html_for_analysis(text) : text

        # Calculer la longueur optimale selon le contenu
        optimal_words = calculate_optimal_summary_length(analysis_text, max_words)

        result = MistralTranslator.summarize(
          text,
          language: target_language,
          max_words: optimal_words,
          style: style,
          context: context
        )

        {
          summary: result,
          original_length: analysis_text.split.size,
          summary_length: optimal_words,
          compression_ratio: (optimal_words.to_f / analysis_text.split.size * 100).round(1)
        }
      end

      # Helper pour traduction multi-style
      def translate_multi_style(text, from:, to:, **options)
        results = {}

        styles = options[:styles] || %i[formal casual]
        styles.each do |style|
          style_context = options[:context] ? "#{options[:context]} (Style: #{style})" : "Style: #{style}"

          begin
            results[style] = MistralTranslator.translate(
              text,
              from: from,
              to: to,
              context: style_context,
              glossary: options[:glossary]
            )
          rescue StandardError => e
            results[style] = { error: e.message }
          end
        end

        results
      end

      # Helper pour validation de locale avec suggestions

      def validate_locale_with_suggestions(locale)
        { valid: true, locale: LocaleHelper.validate_locale!(locale) }
      rescue UnsupportedLanguageError => e
        suggestions = find_locale_suggestions(locale)
        {
          valid: false,
          error: e.message,
          suggestions: suggestions,
          supported_locales: LocaleHelper.supported_locales
        }
      end

      # Helper pour configuration rapide Rails
      def setup_rails_integration(api_key: nil, enable_metrics: true, setup_logging: true)
        MistralTranslator.configure do |config|
          config.api_key = api_key || ENV.fetch("MISTRAL_API_KEY", nil)
          config.enable_metrics = enable_metrics
          config.setup_rails_logging if setup_logging

          # Callbacks Rails-friendly
          if enable_metrics && defined?(Rails)
            config.on_translation_complete = lambda { |_from, _to, _orig_len, _trans_len, _duration|
              Rails.cache.increment("mistral_translator_translations_count", 1)
              Rails.cache.write("mistral_translator_last_translation", Time.now)
            }
          end
        end
      end

      private

      def translate_individually_with_errors(texts, from:, to:, context: nil, glossary: nil)
        # Adapter la signature aux specs tests

        translator = Translator.new
        results = {}

        texts.each_with_index do |text, index|
          results[index] = translator.translate(text, from: from, to: to, context: context, glossary: glossary)
        rescue StandardError => e
          results[index] = { error: e.message }
        end

        results
      end

      def strip_html_for_analysis(html_text)
        # Suppression basique des balises HTML pour l'analyse
        html_text.gsub(/<[^>]*>/, " ").gsub(/\s+/, " ").strip
      end

      def calculate_optimal_summary_length(text, max_words)
        word_count = text.split.size

        case word_count
        when 0..100
          # Texte très court, résumé minimal
          [max_words, word_count / 2].min
        when 101..500
          # Texte court à moyen
          [max_words, word_count / 3].min
        when 501..2000
          # Texte moyen à long
          [max_words, word_count / 4].min
        else
          # Texte très long
          [max_words, word_count / 5].min
        end
      end

      def find_locale_suggestions(invalid_locale)
        return [] unless invalid_locale.is_a?(String)

        supported = LocaleHelper.supported_locales.map(&:to_s)

        # Recherche par similarité basique
        suggestions = supported.select do |locale|
          locale.start_with?(invalid_locale.downcase) ||
            invalid_locale.downcase.start_with?(locale)
        end

        # Si pas de suggestions par préfixe, chercher par distance
        if suggestions.empty?
          suggestions = supported.select do |locale|
            LevenshteinHelpers.levenshtein_distance(invalid_locale.downcase, locale) <= 2
          end
        end

        suggestions.first(3) # Limiter à 3 suggestions
      end

      # Exposer la distance de Levenshtein en privé via délégation pour les tests
      def levenshtein_distance(source_string, target_string)
        LevenshteinHelpers.levenshtein_distance(source_string, target_string)
      end
    end

    # Module pour inclure dans les classes Rails si souhaité
    module RecordHelpers
      def translate_with_mistral(fields, from:, to:, **)
        adapter = MistralTranslator::Adapters::AdapterFactory.build_for(self)
        service = MistralTranslator::Adapters::RecordTranslationService.new(self, fields, adapter: adapter, from: from,
                                                                                          to: to, **)
        service.translate_to_all_locales
      end

      def estimate_translation_cost_for_fields(fields, from:, to:, rate_per_1k_chars: 0.02)
        total_chars = 0

        Array(fields).each do |field|
          content = begin
            public_send("#{field}_#{from}")
          rescue StandardError
            nil
          end
          next unless content

          text = content.respond_to?(:to_plain_text) ? content.to_plain_text : content.to_s
          total_chars += text.length
        end

        MistralTranslator::Helpers.estimate_translation_cost(
          "x" * total_chars, # Dummy text de la bonne longueur
          from: from,
          to: to,
          rate_per_1k_chars: rate_per_1k_chars
        )
      end
    end
  end
end

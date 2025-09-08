# frozen_string_literal: true

module MistralTranslator
  module HelpersExtensions
    # Extensions pour les helpers de traduction
    module TranslationHelpers
      def translate_with_quality_check(text, from:, to:, **options)
        client = Client.new

        # Unique requête avec validation de qualité intégrée
        qp_options = { context: options[:context], glossary: options[:glossary] }
        quality_prompt = PromptBuilder.translation_with_validation_prompt(text, from, to, **qp_options)
        quality_response = client.complete(quality_prompt, context: { from_locale: from, to_locale: to })

        quality_data = ResponseParser.parse_quality_check_response(quality_response)

        {
          translation: quality_data[:translation],
          quality_check: quality_data[:quality_check],
          metadata: quality_data[:metadata]
        }
      end

      def translate_rich_text(text, from:, to:, **options)
        opts = { context: options[:context], glossary: options[:glossary] }
        MistralTranslator.translate(text, from: from, to: to, preserve_html: true, **opts)
      end

      def translate_with_progress(items, from:, to:, **options)
        results = {}
        total = items.size
        processed = 0

        items.each do |key, text|
          results[key] = MistralTranslator.translate(text, from: from, to: to, **options)
          processed += 1
          yield(processed, total, key) if block_given?
        end

        results
      end

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
    end

    # Extensions pour les helpers d'analyse
    module AnalysisHelpers
      def analyze_text_complexity(text)
        words = text.split
        sentences = text.split(/[.!?]+/)
        paragraphs = text.split(/\n\s*\n/)

        {
          word_count: words.size,
          sentence_count: sentences.size,
          paragraph_count: paragraphs.size,
          average_words_per_sentence: words.size.to_f / sentences.size,
          average_sentences_per_paragraph: sentences.size.to_f / paragraphs.size,
          complexity_score: calculate_complexity_score(words, sentences)
        }
      end

      def calculate_complexity_score(words, sentences)
        # Score basique basé sur la longueur moyenne des mots et phrases
        avg_word_length = words.map(&:length).sum.to_f / words.size
        avg_sentence_length = words.size.to_f / sentences.size

        # Normalisation simple (0-100)
        word_score = [avg_word_length * 10, 50].min
        sentence_score = [avg_sentence_length * 2, 50].min

        (word_score + sentence_score).round(1)
      end

      def suggest_optimal_summary_length(text, target_compression: 0.3)
        word_count = text.split.size
        optimal_words = (word_count * target_compression).round

        {
          original_words: word_count,
          suggested_words: optimal_words,
          compression_ratio: (optimal_words.to_f / word_count * 100).round(1)
        }
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
            levenshtein_distance(invalid_locale.downcase, locale) <= 2
          end
        end

        suggestions.first(3) # Limiter à 3 suggestions
      end
    end

    # Extensions pour les helpers de coût
    module CostHelpers
      def estimate_translation_cost(text, from: nil, to: nil, rate_per_1k_chars: 0.02)
        # from et to sont conservés pour l'interface mais pas utilisés dans le calcul
        _ = from
        _ = to
        char_count = text.length
        estimated_cost = (char_count / 1000.0) * rate_per_1k_chars

        {
          character_count: char_count,
          estimated_cost: estimated_cost.round(4),
          rate_per_1k_chars: rate_per_1k_chars,
          currency: "USD",
          supported_locales: LocaleHelper.supported_locales,
          disclaimer: "Estimation basique, coûts réels selon le modèle et le contexte",
          rate_used: rate_per_1k_chars
        }
      end
    end
  end
end

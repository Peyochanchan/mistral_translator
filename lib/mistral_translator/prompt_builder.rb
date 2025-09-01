# frozen_string_literal: true

module MistralTranslator
  class PromptBuilder
    class << self
      def translation_prompt(text, source_language, target_language)
        source_name = LocaleHelper.locale_to_language(source_language)
        target_name = LocaleHelper.locale_to_language(target_language)

        log_prompt_creation("translation", target_language)

        <<~PROMPT
          Tu es un traducteur professionnel. Tu ne dois pas halluciner et uniquement traduire le texte suivant en respectant ces règles strictes :
          1. Langue source, locale : #{source_name} (#{source_language})
          2. Langue cible, locale : #{target_name} (#{target_language})
          3. IMPORTANT : Le champ "target" DOIT contenir la traduction en #{target_name}, PAS le texte original
          4. Conserve le style, le ton et le format du texte original
          5. Format de réponse obligatoire en JSON :
          {
            "content": {
              "source": "texte original",
              "target": "texte traduit"
            },
            "metadata": {
              "source": "#{source_language}",
              "target": "#{target_language}"
            }
          }

          Texte à traduire :
          #{text}
        PROMPT
      end

      def summary_prompt(text, max_words, target_language = "fr")
        language_name = LocaleHelper.locale_to_language(target_language)

        log_prompt_creation("summary", target_language)

        <<~PROMPT
          Tu es un assistant spécialisé dans la création de résumés. Tu ne dois pas halluciner et générer un résumé en respectant ces règles strictes :
          1. Longueur maximale : #{max_words} mots
          2. Langue : #{language_name} (#{target_language})
          3. Conserve les informations essentielles du texte original
          4. Format de réponse obligatoire en JSON :
          {
            "content": {
              "source": "texte original",
              "target": "texte résumé en #{language_name}"
            },
            "metadata": {
              "source": "original",
              "target": "summary",
              "word_count": #{max_words},
              "language": "#{target_language}"
            }
          }

          Texte à résumer :
          #{text}
        PROMPT
      end

      def bulk_translation_prompt(texts, source_language, target_language)
        source_name = LocaleHelper.locale_to_language(source_language)
        target_name = LocaleHelper.locale_to_language(target_language)

        log_prompt_creation("bulk_translation", target_language)

        # Formatage des textes avec index
        indexed_texts = texts.each_with_index.map { |text, index| "#{index + 1}. #{text}" }.join("\n")

        <<~PROMPT
          Tu es un traducteur professionnel. Traduis chacun des textes suivants de #{source_name} vers #{target_name}.
          Conserve le style, le ton et le format de chaque texte original.

          Format de réponse obligatoire en JSON :
          {
            "translations": [
              {
                "index": 1,
                "source": "texte original 1",
                "target": "texte traduit 1"
              },
              {
                "index": 2,
                "source": "texte original 2",#{" "}
                "target": "texte traduit 2"
              }
            ],
            "metadata": {
              "source_language": "#{source_language}",
              "target_language": "#{target_language}",
              "count": #{texts.length}
            }
          }

          Textes à traduire :
          #{indexed_texts}
        PROMPT
      end

      private

      def log_prompt_creation(type, language)
        message = "[MistralTranslator] #{type.capitalize} prompt created for language: #{language}"

        if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger.info message
        elsif ENV["MISTRAL_TRANSLATOR_DEBUG"]
          puts message
        end
      end
    end
  end
end

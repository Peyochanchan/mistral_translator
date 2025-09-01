# frozen_string_literal: true

require_relative "logger"

module MistralTranslator
  module PromptBuilder
    class << self
      def translation_prompt(text, source_language, target_language)
        source_name = LocaleHelper.locale_to_language(source_language)
        target_name = LocaleHelper.locale_to_language(target_language)

        <<~PROMPT
          Tu es un traducteur professionnel. Traduis le texte suivant de #{source_name} vers #{target_name}.

          RÈGLES :
          - Traduis fidèlement sans ajouter d'informations
          - Conserve le style, ton et format original
          - Réponds UNIQUEMENT en JSON valide

          FORMAT OBLIGATOIRE :
          {
            "content": {
              "source": "texte original",
              "target": "texte traduit en #{target_name}"
            },
            "metadata": {
              "source_language": "#{source_language}",
              "target_language": "#{target_language}",
              "operation": "translation"
            }
          }

          TEXTE À TRADUIRE :
          #{text}
        PROMPT
      end

      def bulk_translation_prompt(texts, source_language, target_language)
        source_name = LocaleHelper.locale_to_language(source_language)
        target_name = LocaleHelper.locale_to_language(target_language)

        <<~PROMPT
          Tu es un traducteur professionnel. Traduis les textes suivants de #{source_name} vers #{target_name}.

          RÈGLES :
          - Traduis fidèlement chaque texte sans ajouter d'informations
          - Conserve le style, ton et format originaux
          - Réponds UNIQUEMENT en JSON valide

          FORMAT OBLIGATOIRE :
          {
            "translations": [
              {
                "index": 1,
                "source": "texte original 1",
                "target": "texte traduit 1"
              },
              {
                "index": 2,
                "source": "texte original 2",
                "target": "texte traduit 2"
              }
            ],
            "metadata": {
              "source_language": "#{source_language}",
              "target_language": "#{target_language}",
              "count": #{texts.length},
              "operation": "bulk_translation"
            }
          }

          TEXTES À TRADUIRE :
          #{texts.map.with_index { |text, i| "#{i + 1}. #{text}" }.join("\n")}
        PROMPT
      end

      def summary_prompt(text, max_words, target_language = "fr")
        target_name = LocaleHelper.locale_to_language(target_language)

        <<~PROMPT
          Tu es un rédacteur professionnel. Résume le texte suivant en #{target_name}.

          RÈGLES :
          - Résume fidèlement sans ajouter d'informations
          - Maximum #{max_words} mots
          - Conserve les informations essentielles
          - Réponds UNIQUEMENT en JSON valide

          FORMAT OBLIGATOIRE :
          {
            "content": {
              "source": "texte original",
              "target": "résumé en #{target_name}"
            },
            "metadata": {
              "source_language": "original",
              "target_language": "#{target_language}",
              "word_count": #{max_words},
              "operation": "summarization"
            }
          }

          TEXTE À RÉSUMER :
          #{text}
        PROMPT
      end

      def summary_and_translation_prompt(text, source_language, target_language, max_words)
        source_name = LocaleHelper.locale_to_language(source_language)
        target_name = LocaleHelper.locale_to_language(target_language)

        <<~PROMPT
          Tu es un rédacteur professionnel. Résume ET traduis le texte suivant de #{source_name} vers #{target_name}.

          RÈGLES :
          - Résume fidèlement sans ajouter d'informations
          - Traduis le résumé en #{target_name}
          - Maximum #{max_words} mots
          - Réponds UNIQUEMENT en JSON valide

          FORMAT OBLIGATOIRE :
          {
            "content": {
              "source": "texte original",
              "target": "résumé traduit en #{target_name}"
            },
            "metadata": {
              "source_language": "#{source_language}",
              "target_language": "#{target_language}",
              "word_count": #{max_words},
              "operation": "summarization_and_translation"
            }
          }

          TEXTE À RÉSUMER ET TRADUIRE :
          #{text}
        PROMPT
      end

      def tiered_summary_prompt(text, target_language, short, medium, long)
        target_name = LocaleHelper.locale_to_language(target_language)

        <<~PROMPT
          Tu es un rédacteur professionnel. Crée trois résumés du texte suivant en #{target_name}.

          RÈGLES :
          - Résume fidèlement sans ajouter d'informations
          - Respecte strictement les longueurs demandées
          - Réponds UNIQUEMENT en JSON valide

          FORMAT OBLIGATOIRE :
          {
            "content": {
              "source": "texte original",
              "target": "résumés en #{target_name}"
            },
            "metadata": {
              "source_language": "original",
              "target_language": "#{target_language}",
              "summaries": {
                "short": #{short},
                "medium": #{medium},
                "long": #{long}
              },
              "operation": "tiered_summarization"
            }
          }

          TEXTE À RÉSUMER :
          #{text}
        PROMPT
      end

      def language_detection_prompt(text)
        <<~PROMPT
          Tu es un expert en linguistique. Détecte la langue du texte suivant.

          RÈGLES :
          - Identifie la langue principale
          - Utilise le code ISO 639-1 (ex: 'fr', 'en', 'es')
          - Réponds UNIQUEMENT en JSON valide

          FORMAT OBLIGATOIRE :
          {
            "content": {
              "source": "texte analysé",
              "target": "langue détectée"
            },
            "metadata": {
              "detected_language": "code_iso",
              "operation": "language_detection"
            }
          }

          TEXTE À ANALYSER :
          #{text}
        PROMPT
      end

      private

      def log_prompt_generation(prompt_type, source_locale, target_locale)
        message = "Generated #{prompt_type} prompt for #{source_locale} -> #{target_locale}"
        Logger.debug_if_verbose(message, sensitive: false)
      end

      def log_prompt_debug(prompt)
        return unless ENV["MISTRAL_TRANSLATOR_DEBUG"]

        if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger.info message
        elsif ENV["MISTRAL_TRANSLATOR_DEBUG"]
          # Log de debug seulement si mode verbose activé
          Logger.debug_if_verbose(message, sensitive: false)
        end
      end
    end
  end
end

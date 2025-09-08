# frozen_string_literal: true

require_relative "logger"
require_relative "prompt_helpers"
require_relative "prompt_metadata_helpers"

module MistralTranslator
  module PromptBuilder
    extend PromptHelpers::ContextBuilder
    extend PromptHelpers::HtmlInstructions
    extend PromptHelpers::FormatInstructions
    extend PromptMetadataHelpers

    class << self
      def translation_prompt(text, source_language, target_language, **options)
        source_name = LocaleHelper.locale_to_language(source_language)
        target_name = LocaleHelper.locale_to_language(target_language)

        # Construction du contexte enrichi
        context_section = build_context_section(options[:context], options[:glossary])
        html_instruction = options[:preserve_html] ? build_html_preservation_instruction : ""

        # Extraire les valeurs pour les métadonnées
        context = options[:context]
        glossary = options[:glossary]
        preserve_html = options[:preserve_html]

        <<~PROMPT
          Tu es un traducteur professionnel. Traduis le texte suivant de #{source_name} vers #{target_name}.
          #{context_section}
          RÈGLES :
          - Traduis fidèlement sans ajouter d'informations
          - Conserve le style, ton et format original#{html_instruction}
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
              "operation": "translation"#{build_metadata_additions(context, glossary, preserve_html)}
            }
          }

          TEXTE À TRADUIRE :
          #{text}
        PROMPT
      end

      # rubocop:disable Metrics/MethodLength
      def bulk_translation_prompt(texts, source_language, target_language, **options)
        source_name = LocaleHelper.locale_to_language(source_language)
        target_name = LocaleHelper.locale_to_language(target_language)

        context_section = build_context_section(options[:context], options[:glossary])
        html_instruction = options[:preserve_html] ? build_html_preservation_instruction : ""

        # Extraire les valeurs pour les métadonnées
        context = options[:context]
        glossary = options[:glossary]
        preserve_html = options[:preserve_html]

        <<~PROMPT
          Tu es un traducteur professionnel. Traduis les textes suivants de #{source_name} vers #{target_name}.
          #{context_section}
          RÈGLES :
          - Traduis fidèlement chaque texte sans ajouter d'informations
          - Conserve le style, ton et format originaux#{html_instruction}
          - Maintiens la cohérence terminologique entre tous les textes
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
              "operation": "bulk_translation"#{build_metadata_additions(context, glossary, preserve_html)}
            }
          }

          TEXTES À TRADUIRE :
          #{texts.map.with_index { |text, i| "#{i + 1}. #{text}" }.join("\n")}
        PROMPT
      end
      # rubocop:enable Metrics/MethodLength

      def summary_prompt(text, max_words, target_language = "fr", context: nil, style: nil)
        target_name = LocaleHelper.locale_to_language(target_language)

        context_section = build_summary_context_section(context, style)
        style_instruction = build_style_instruction(style)

        <<~PROMPT
          Tu es un rédacteur professionnel. Résume le texte suivant en #{target_name}.
          #{context_section}
          RÈGLES :
          - Résume fidèlement sans ajouter d'informations
          - Maximum #{max_words} mots
          - Conserve les informations essentielles#{style_instruction}
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
              "operation": "summarization"#{build_summary_metadata_additions(context, style)}
            }
          }

          TEXTE À RÉSUMER :
          #{text}
        PROMPT
      end

      def summary_and_translation_prompt(text, source_language, target_language, max_words, **options)
        source_name = LocaleHelper.locale_to_language(source_language)
        target_name = LocaleHelper.locale_to_language(target_language)

        context_section = build_summary_context_section(options[:context], options[:style])
        style_instruction = build_style_instruction(options[:style])

        # Extraire les valeurs pour les métadonnées
        context = options[:context]
        style = options[:style]

        <<~PROMPT
          Tu es un rédacteur professionnel. Résume ET traduis le texte suivant de #{source_name} vers #{target_name}.
          #{context_section}
          RÈGLES :
          - Résume fidèlement sans ajouter d'informations
          - Traduis le résumé en #{target_name}
          - Maximum #{max_words} mots#{style_instruction}
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
              "operation": "summarization_and_translation"#{build_summary_metadata_additions(context, style)}
            }
          }

          TEXTE À RÉSUMER ET TRADUIRE :
          #{text}
        PROMPT
      end

      def tiered_summary_prompt(text, target_language, **options)
        target_name = LocaleHelper.locale_to_language(target_language)

        context_section = build_summary_context_section(options[:context], options[:style])
        style_instruction = build_style_instruction(options[:style])

        # Extraire les valeurs pour les métadonnées
        context = options[:context]
        style = options[:style]

        <<~PROMPT
          Tu es un rédacteur professionnel. Crée trois résumés du texte suivant en #{target_name}.
          #{context_section}
          RÈGLES :
          - Résume fidèlement sans ajouter d'informations
          - Respecte strictement les longueurs demandées
          - Court: #{options[:short]} mots, Moyen: #{options[:medium]} mots, Long: #{options[:long]} mots#{style_instruction}
          - Réponds UNIQUEMENT en JSON valide

          FORMAT OBLIGATOIRE :
          {
            "content": {
              "source": "texte original",
              "summaries": {
                "short": "résumé court (#{options[:short]} mots)",
                "medium": "résumé moyen (#{options[:medium]} mots)",
                "long": "résumé long (#{options[:long]} mots)"
              }
            },
            "metadata": {
              "source_language": "original",
              "target_language": "#{target_language}",
              "summaries": {
                "short": #{options[:short]},
                "medium": #{options[:medium]},
                "long": #{options[:long]}
              },
              "operation": "tiered_summarization"#{build_summary_metadata_additions(context, style)}
            }
          }

          TEXTE À RÉSUMER :
          #{text}
        PROMPT
      end

      def language_detection_prompt(text, confidence_score: false)
        confidence_instruction = if confidence_score
                                   ', "confidence": score_de_confiance_entre_0_et_1'
                                 else
                                   ""
                                 end

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
              "detected_language": "code_iso"#{confidence_instruction},
              "operation": "language_detection"
            }
          }

          TEXTE À ANALYSER :
          #{text}
        PROMPT
      end

      # Nouveau : Prompt pour traduction avec validation de qualité
      def translation_with_validation_prompt(text, source_language, target_language, **)
        base_prompt = translation_prompt(text, source_language, target_language, **)

        base_prompt.sub(
          '"operation": "translation"',
          '"operation": "translation_with_validation",
          "quality_check": {
            "terminology_consistency": "vérifié",
            "style_preservation": "vérifié",
            "completeness": "vérifié"
          }'
        )
      end
    end
  end
end

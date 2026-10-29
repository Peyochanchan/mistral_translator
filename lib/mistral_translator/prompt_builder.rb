# frozen_string_literal: true

require_relative "logger"
require_relative "prompt_helpers"
require_relative "prompt_metadata_helpers"
require_relative "prompt"

module MistralTranslator
  module PromptBuilder
    extend PromptHelpers::ContextBuilder
    extend PromptHelpers::HtmlInstructions
    extend PromptMetadataHelpers

    class << self
      def translation_prompt(text, source_language, target_language, **options)
        source_name = LocaleHelper.prompt_language_name(source_language)
        target_name = LocaleHelper.prompt_language_name(target_language)

        context, glossary, preserve_html = options.values_at(:context, :glossary, :preserve_html)
        context_section = build_context_section(context, glossary)
        html_instruction = preserve_html ? build_html_preservation_instruction : ""
        quality_check = options.fetch(:quality_check, false)
        operation = quality_check ? "translation_with_validation" : "translation"
        metadata_additions = build_metadata_additions(context, glossary, preserve_html, quality_check: quality_check)

        Prompt.new(instructions: <<~PROMPT, text: text)
          Tu es un traducteur professionnel. Traduis le texte fourni.
          Langue source : #{source_name}. Langue cible : #{target_name}.
          #{context_section}
          RÈGLES :
          - Traduis fidèlement sans ajouter d'informations
          - Conserve le style, ton et format original#{html_instruction}
          - #{Prompt::DATA_RULE}
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
              "operation": "#{operation}"#{metadata_additions}
            }
          }
        PROMPT
      end

      def summary_prompt(text, max_words, target_language = "fr", context: nil, style: nil)
        target_name = LocaleHelper.prompt_language_name(target_language)

        context_section = build_summary_context_section(context, style)
        style_instruction = build_style_instruction(style)

        Prompt.new(instructions: <<~PROMPT, text: text)
          Tu es un rédacteur professionnel. Résume le texte fourni en #{target_name}.
          #{context_section}
          RÈGLES :
          - Résume fidèlement sans ajouter d'informations
          - Maximum #{max_words} mots
          - Conserve les informations essentielles#{style_instruction}
          - #{Prompt::DATA_RULE}
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
        PROMPT
      end

      def summary_and_translation_prompt(text, source_language, target_language, max_words, **options)
        source_name = LocaleHelper.prompt_language_name(source_language)
        target_name = LocaleHelper.prompt_language_name(target_language)

        context_section = build_summary_context_section(options[:context], options[:style])
        style_instruction = build_style_instruction(options[:style])

        # Extraire les valeurs pour les métadonnées
        context = options[:context]
        style = options[:style]

        Prompt.new(instructions: <<~PROMPT, text: text)
          Tu es un rédacteur professionnel. Résume ET traduis le texte fourni.
          Langue source : #{source_name}. Langue cible : #{target_name}.
          #{context_section}
          RÈGLES :
          - Résume fidèlement sans ajouter d'informations
          - Traduis le résumé en #{target_name}
          - Maximum #{max_words} mots#{style_instruction}
          - #{Prompt::DATA_RULE}
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
        PROMPT
      end

      def language_detection_prompt(text, confidence_score: false)
        confidence_instruction = if confidence_score
                                   ', "confidence": score_de_confiance_entre_0_et_1'
                                 else
                                   ""
                                 end

        Prompt.new(instructions: <<~PROMPT, text: text)
          Tu es un expert en linguistique. Détecte la langue du texte fourni.

          RÈGLES :
          - Identifie la langue principale
          - Utilise le code ISO 639-1 (ex: 'fr', 'en', 'es')
          - #{Prompt::DATA_RULE}
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
        PROMPT
      end

      # Nouveau : Prompt pour traduction avec validation de qualité
      def translation_with_validation_prompt(text, source_language, target_language, **)
        translation_prompt(text, source_language, target_language, **, quality_check: true)
      end
    end
  end
end

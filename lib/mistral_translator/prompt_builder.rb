# frozen_string_literal: true

require_relative "logger"

module MistralTranslator
  module PromptBuilder
    class << self
      def translation_prompt(text, source_language, target_language, context: nil, glossary: nil, preserve_html: false)
        source_name = LocaleHelper.locale_to_language(source_language)
        target_name = LocaleHelper.locale_to_language(target_language)

        # Construction du contexte enrichi
        context_section = build_context_section(context, glossary)
        html_instruction = preserve_html ? build_html_preservation_instruction : ""

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

      def bulk_translation_prompt(texts, source_language, target_language, context: nil, glossary: nil,
                                  preserve_html: false)
        source_name = LocaleHelper.locale_to_language(source_language)
        target_name = LocaleHelper.locale_to_language(target_language)

        context_section = build_context_section(context, glossary)
        html_instruction = preserve_html ? build_html_preservation_instruction : ""

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

      def summary_and_translation_prompt(text, source_language, target_language, max_words, context: nil, style: nil)
        source_name = LocaleHelper.locale_to_language(source_language)
        target_name = LocaleHelper.locale_to_language(target_language)

        context_section = build_summary_context_section(context, style)
        style_instruction = build_style_instruction(style)

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

      def tiered_summary_prompt(text, target_language, short, medium, long, context: nil, style: nil)
        target_name = LocaleHelper.locale_to_language(target_language)

        context_section = build_summary_context_section(context, style)
        style_instruction = build_style_instruction(style)

        <<~PROMPT
          Tu es un rédacteur professionnel. Crée trois résumés du texte suivant en #{target_name}.
          #{context_section}
          RÈGLES :
          - Résume fidèlement sans ajouter d'informations
          - Respecte strictement les longueurs demandées
          - Court: #{short} mots, Moyen: #{medium} mots, Long: #{long} mots#{style_instruction}
          - Réponds UNIQUEMENT en JSON valide

          FORMAT OBLIGATOIRE :
          {
            "content": {
              "source": "texte original",
              "summaries": {
                "short": "résumé court (#{short} mots)",
                "medium": "résumé moyen (#{medium} mots)",#{" "}
                "long": "résumé long (#{long} mots)"
              }
            },
            "metadata": {
              "source_language": "original",
              "target_language": "#{target_language}",
              "summaries": {
                "short": #{short},
                "medium": #{medium},
                "long": #{long}
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
      def translation_with_validation_prompt(text, source_language, target_language, context: nil, glossary: nil)
        base_prompt = translation_prompt(text, source_language, target_language, context: context, glossary: glossary)

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

      private

      def build_context_section(context, glossary)
        sections = []

        sections << "CONTEXTE : #{context}" if context && !context.to_s.strip.empty?

        if glossary && !glossary.to_s.strip.empty? && glossary.is_a?(Hash) && glossary.any?
          glossary_text = glossary.map { |key, value| "#{key} → #{value}" }.join(", ")
          sections << "GLOSSAIRE (à respecter strictement) : #{glossary_text}"
        end

        sections.any? ? "\n#{sections.join("\n")}\n" : ""
      end

      def build_summary_context_section(context, style)
        sections = []

        sections << "CONTEXTE : #{context}" if context && !context.to_s.strip.empty?

        sections << "STYLE REQUIS : #{style}" if style && !style.to_s.strip.empty?

        sections.any? ? "\n#{sections.join("\n")}\n" : ""
      end

      def build_html_preservation_instruction
        "\n          - IMPORTANT : Préserve exactement toutes les balises HTML et leur structure"
      end

      def build_style_instruction(style)
        return "" unless style && !style.to_s.strip.empty?

        style_rules = {
          "formal" => "Utilise un style formel et professionnel",
          "casual" => "Utilise un style décontracté et accessible",
          "technical" => "Maintiens la précision technique et la terminologie spécialisée",
          "marketing" => "Adopte un ton engageant et persuasif",
          "academic" => "Utilise un style académique rigoureux"
        }

        instruction = style_rules[style.to_s] || "Adopte le style : #{style}"
        "\n          - STYLE : #{instruction}"
      end

      def build_metadata_additions(context, glossary, preserve_html)
        additions = []

        additions << '"has_context": true' if context && !context.to_s.strip.empty?
        additions << '"has_glossary": true' if glossary && !glossary.to_s.strip.empty? && glossary.any?
        additions << '"preserve_html": true' if preserve_html

        additions.any? ? ",\n              #{additions.join(",\n              ")}" : ""
      end

      def build_summary_metadata_additions(context, style)
        additions = []

        additions << '"has_context": true' if context && !context.to_s.strip.empty?
        additions << %("style": "#{style}") if style && !style.to_s.strip.empty?

        additions.any? ? ",\n              #{additions.join(",\n              ")}" : ""
      end

      def log_prompt_generation(prompt_type, source_locale, target_locale)
        message = "Generated #{prompt_type} prompt for #{source_locale} -> #{target_locale}"
        Logger.debug_if_verbose(message, sensitive: false)
      end

      def log_prompt_debug(_prompt)
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

# frozen_string_literal: true

module MistralTranslator
  module PromptHelpers
    # Helper pour la construction des sections de contexte
    module ContextBuilder
      def build_context_section(context, glossary)
        return "" unless context || glossary

        sections = []
        sections << "CONTEXTE : #{context}" if context && !context.to_s.strip.empty?
        sections << "GLOSSAIRE : #{glossary}" if glossary && !glossary.to_s.strip.empty?

        sections.any? ? "\n#{sections.join("\n")}\n" : ""
      end

      def build_summary_context_section(context, style)
        return "" unless context || style

        sections = []
        sections << "CONTEXTE : #{context}" if context && !context.to_s.strip.empty?
        sections << "STYLE : #{style}" if style && !style.to_s.strip.empty?

        sections.any? ? "\n#{sections.join("\n")}\n" : ""
      end

      def build_style_instruction(style)
        return "" unless style

        case style.to_s.downcase
        when "formal"
          "\nUtilise un style formel et professionnel."
        when "casual"
          "\nUtilise un style décontracté et familier."
        when "academic"
          "\nUtilise un style académique et précis."
        when "marketing"
          "\nUtilise un style marketing et persuasif."
        else
          ""
        end
      end
    end

    # Helper pour les instructions HTML
    module HtmlInstructions
      def build_html_preservation_instruction
        <<~HTML_INSTRUCTION

          IMPORTANT : Préserve tous les éléments HTML (balises, attributs, structure).
          Ne traduis que le contenu textuel à l'intérieur des balises.
        HTML_INSTRUCTION
      end

      def build_html_validation_instruction
        <<~HTML_VALIDATION

          IMPORTANT : Vérifie que le HTML est valide et bien formé.
          Corrige toute erreur de structure HTML si nécessaire.
        HTML_VALIDATION
      end
    end

    # Helper pour les instructions de formatage
    module FormatInstructions
      def build_json_format_instruction
        <<~JSON_INSTRUCTION

          FORMAT DE RÉPONSE : Réponds UNIQUEMENT avec un objet JSON valide.
          Pas de texte avant ou après le JSON.
        JSON_INSTRUCTION
      end

      def build_batch_format_instruction
        <<~BATCH_INSTRUCTION

          FORMAT DE RÉPONSE : Réponds avec un tableau JSON contenant les traductions dans l'ordre.
          Chaque élément doit être la traduction correspondante.
        BATCH_INSTRUCTION
      end
    end
  end
end

# frozen_string_literal: true

module MistralTranslator
  module PromptHelpers
    # Helper pour la construction des sections de contexte
    module ContextBuilder
      # Seule mise en forme du contexte et du glossaire dans les prompts de traduction
      def build_context_section(context, glossary)
        sections = []
        sections << "CONTEXTE : #{context}" if context_present?(context)
        sections << glossary_line(glossary) if glossary_present?(glossary)

        sections.any? ? "\n#{sections.join("\n")}\n" : ""
      end

      def glossary_line(glossary)
        return "GLOSSAIRE : #{glossary.to_s.strip}" unless glossary.is_a?(Hash)

        terms = glossary.map { |source, target| "#{source} → #{target}" }.join(", ")
        "GLOSSAIRE (à respecter strictement) : #{terms}"
      end

      def context_present?(context)
        !context.to_s.strip.empty?
      end

      # Le glossaire est un Hash ou une chaîne : String ne répond pas à #any?
      def glossary_present?(glossary)
        return glossary.any? if glossary.is_a?(Hash)

        !glossary.to_s.strip.empty?
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
    end
  end
end

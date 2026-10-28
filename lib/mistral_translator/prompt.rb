# frozen_string_literal: true

module MistralTranslator
  # Prompt envoyé en deux messages : les consignes (system) et le texte à traiter (user).
  # Le texte reste une donnée : il n'est jamais mélangé aux consignes.
  Prompt = Data.define(:system, :user) do
    def self.for_text(instructions, text)
      new(system: instructions, user: "#{PromptBuilder::TEXT_START}\n#{text}\n#{PromptBuilder::TEXT_END}")
    end

    def messages
      [
        { role: "system", content: system },
        { role: "user", content: user }
      ]
    end

    # Forme en un seul texte, pour les appelants qui attendent une String.
    def to_s
      "#{system}\n#{user}"
    end

    def length
      to_s.length
    end
  end
end

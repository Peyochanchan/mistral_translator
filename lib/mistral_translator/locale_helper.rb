# frozen_string_literal: true

module MistralTranslator
  # Fonctions historiques sur les locales, qui délèguent à Locale.
  module LocaleHelper
    # Langues CLDR, générées par bin/generate_languages
    LANGUAGES = Locale::LANGUAGES

    # Nom de chaque langue dans sa propre langue
    SUPPORTED_LANGUAGES = LANGUAGES.transform_values { |names| names["native"].downcase }.freeze

    # Noms acceptés à la place du code
    LANGUAGE_ALIASES = Locale::NAMES

    class << self
      def locale_to_language(locale)
        found = Locale.find(locale)
        found ? SUPPORTED_LANGUAGES[found.language] : locale.to_s
      end

      # Nom français suivi du code, pour les prompts : « portugais (Brésil) (pt-BR) »
      def prompt_language_name(locale)
        Locale.find(locale)&.prompt_name || locale.to_s
      end

      def language_to_locale(language)
        normalized_language = language.to_s.downcase.strip
        LANGUAGE_ALIASES.fetch(normalized_language, normalized_language)
      end

      def supported_locales
        SUPPORTED_LANGUAGES.keys
      end

      def supported_languages
        SUPPORTED_LANGUAGES.values
      end

      def locale_supported?(locale)
        !Locale.find(locale).nil?
      end

      # Forme canonique de la locale ("pt-BR") ; UnsupportedLanguageError si elle est inconnue
      def validate_locale!(locale)
        Locale.parse(locale).to_s
      end

      # Sous-étiquette de langue seule, sans vérification : "fr-FR" → "fr"
      def normalize_locale(locale)
        return "" if locale.nil? || locale.to_s.empty?

        normalized = locale.to_s.downcase
        return "" if normalized.empty?

        # Diviser par "-" et prendre la première partie
        first_part = normalized.split("-").first
        return "" if first_part.nil? || first_part.empty?

        # Diviser par "_" et prendre la première partie
        result = first_part.split("_").first
        return "" if result.nil? || result.empty?

        result
      end

      # Méthode pour obtenir une liste formatée des langues supportées
      def supported_languages_list
        SUPPORTED_LANGUAGES.map { |code, name| "#{code} (#{name})" }.join(", ")
      end
    end
  end
end

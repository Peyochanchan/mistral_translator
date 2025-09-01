# frozen_string_literal: true

module MistralTranslator
  module LocaleHelper
    SUPPORTED_LANGUAGES = {
      "fr" => "français",
      "en" => "english",
      "es" => "español",
      "pt" => "português",
      "de" => "deutsch",
      "it" => "italiano",
      "nl" => "nederlands",
      "ru" => "русский",
      "mg" => "malagasy",
      "ja" => "日本語",
      "ko" => "한국어",
      "zh" => "中文",
      "ar" => "العربية"
    }.freeze

    # Mapping des noms alternatifs vers les codes de langue
    LANGUAGE_ALIASES = {
      "french" => "fr",
      "german" => "de",
      "spanish" => "es",
      "portuguese" => "pt",
      "italian" => "it",
      "dutch" => "nl",
      "russian" => "ru",
      "malagasy" => "mg",
      "japanese" => "ja",
      "korean" => "ko",
      "chinese" => "zh",
      "arabic" => "ar"
    }.freeze

    class << self
      def locale_to_language(locale)
        locale_code = normalize_locale(locale)
        SUPPORTED_LANGUAGES[locale_code] || locale_code.to_s
      end

      def language_to_locale(language)
        normalized_language = language.to_s.downcase.strip

        # Vérifier d'abord les alias
        return LANGUAGE_ALIASES[normalized_language] if LANGUAGE_ALIASES.key?(normalized_language)

        # Recherche directe par valeur
        found_locale = SUPPORTED_LANGUAGES.find { |_, lang| lang.downcase == normalized_language }
        return found_locale[0] if found_locale

        # Retourne la langue telle quelle si pas trouvée
        normalized_language
      end

      def supported_locales
        SUPPORTED_LANGUAGES.keys
      end

      def supported_languages
        SUPPORTED_LANGUAGES.values
      end

      def locale_supported?(locale)
        SUPPORTED_LANGUAGES.key?(normalize_locale(locale))
      end

      def validate_locale!(locale)
        normalized = normalize_locale(locale)
        raise UnsupportedLanguageError, normalized unless locale_supported?(normalized)

        normalized
      end

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

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

    class << self
      def locale_to_language(locale)
        locale_code = normalize_locale(locale)
        SUPPORTED_LANGUAGES[locale_code] || locale_code.to_s
      end

      def language_to_locale(language)
        normalized_language = language.to_s.downcase.strip

        # Recherche directe par valeur
        found_locale = SUPPORTED_LANGUAGES.find { |_, lang| lang.downcase == normalized_language }
        return found_locale[0] if found_locale

        # Recherche partielle (pour "french" -> "français")
        partial_match = SUPPORTED_LANGUAGES.find do |_, lang|
          lang.downcase.include?(normalized_language) || normalized_language.include?(lang.downcase)
        end
        return partial_match[0] if partial_match

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
        locale.to_s.downcase.split("-").first.split("_").first
      end

      # Méthode pour obtenir une liste formatée des langues supportées
      def supported_languages_list
        SUPPORTED_LANGUAGES.map { |code, name| "#{code} (#{name})" }.join(", ")
      end
    end
  end
end

# frozen_string_literal: true

require "json"

module MistralTranslator
  # Une locale BCP 47 : une langue, et éventuellement une écriture et une région
  # ("fr", "pt-BR", "zh-Hant-TW", "haw"). Objet valeur : deux locales aux mêmes
  # sous-étiquettes sont égales. Chaque sous-étiquette est vérifiée contre les
  # données CLDR de data/, générées par bin/generate_languages.
  Locale = Data.define(:language, :script, :region)

  class Locale
    load_data = ->(name) { JSON.parse(File.read(File.expand_path("data/#{name}.json", __dir__)), freeze: true) }

    LANGUAGES = load_data.call("languages")
    SCRIPTS = load_data.call("scripts")
    REGIONS = load_data.call("regions")

    # Code ISO 639-3 des langues qui ont un code à deux lettres : "hat" → "ht"
    ALPHA3 = LANGUAGES.filter_map { |code, names| [names["alpha3"], code] if names["alpha3"] }.to_h.freeze

    # Noms français, anglais et natifs acceptés à la place du code. Un nom porté
    # par plusieurs langues (« konkani ») est écarté : il faut alors le code.
    NAMES = LANGUAGES
            .flat_map { |code, names| names.values_at("fr", "en", "native").map { |name| [name.downcase, code] } }
            .uniq
            .group_by(&:first)
            .filter_map { |name, entries| [name, entries.first.last] if entries.one? }
            .to_h.freeze

    # langue[-écriture][-région], séparées par "-" ou "_". Les variantes et les
    # extensions ("ca-ES-valencia", "en-US-u-ca-gregory") ne sont pas acceptées.
    TAG = /\A(?<language>[a-z]{2,3})(?:[-_](?<script>[a-z]{4}))?(?:[-_](?<region>[a-z]{2}|\d{3}))?\z/i

    class << self
      # Locale désignée par un code ou un nom de langue ; UnsupportedLanguageError sinon.
      def parse(input)
        find(input) || raise(UnsupportedLanguageError, input.to_s)
      end

      # Comme parse, mais renvoie nil pour une entrée inconnue.
      def find(input)
        return input if input.is_a?(Locale)

        text = input.to_s.strip
        from_tag(text) || from_name(text)
      end

      private

      def from_tag(text)
        return unless (match = TAG.match(text))

        code = match[:language].downcase
        language = LANGUAGES.key?(code) ? code : ALPHA3[code]
        script = match[:script]&.capitalize
        region = match[:region]&.upcase
        new(language:, script:, region:) if language && known?(SCRIPTS, script) && known?(REGIONS, region)
      end

      def known?(table, code) = code.nil? || table.key?(code)

      def from_name(text)
        language = NAMES[text.downcase]
        new(language:) if language
      end
    end

    def initialize(language:, script: nil, region: nil)
      super
    end

    # Forme canonique BCP 47 : "pt-BR", "zh-Hant-TW"
    def to_s = [language, script, region].compact.join("-")

    # Nom français suivi du code, pour les prompts : « portugais (Brésil) (pt-BR) »
    def prompt_name
      name = LANGUAGES.dig(language, "fr")
      details = [SCRIPTS.dig(script, "fr"), REGIONS.dig(region, "fr")].compact
      name = "#{name} (#{details.join(", ")})" if details.any?
      "#{name} (#{self})"
    end
  end
end

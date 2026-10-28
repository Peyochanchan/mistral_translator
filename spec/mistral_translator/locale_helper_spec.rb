# frozen_string_literal: true

RSpec.describe MistralTranslator::LocaleHelper do
  describe ".locale_to_language" do
    it "converts known locales to language names" do
      expect(described_class.locale_to_language("fr")).to eq("français")
      expect(described_class.locale_to_language("en")).to eq("english")
      expect(described_class.locale_to_language("es")).to eq("español")
      expect(described_class.locale_to_language("de")).to eq("deutsch")
    end

    it "handles unknown locales" do
      expect(described_class.locale_to_language("xx")).to eq("xx")
      expect(described_class.locale_to_language("unknown")).to eq("unknown")
    end

    it "normalizes complex locales" do
      expect(described_class.locale_to_language("fr-FR")).to eq("français")
      expect(described_class.locale_to_language("en_US")).to eq("english")
      expect(described_class.locale_to_language("ES-es")).to eq("español")
    end
  end

  describe ".language_to_locale" do
    it "converts known language names to locale codes" do
      expect(described_class.language_to_locale("français")).to eq("fr")
      expect(described_class.language_to_locale("english")).to eq("en")
      expect(described_class.language_to_locale("español")).to eq("es")
    end

    it "handles case insensitivity" do
      expect(described_class.language_to_locale("FRANÇAIS")).to eq("fr")
      expect(described_class.language_to_locale("English")).to eq("en")
      expect(described_class.language_to_locale("  español  ")).to eq("es")
    end

    it "handles partial matches" do
      expect(described_class.language_to_locale("french")).to eq("fr")
      expect(described_class.language_to_locale("german")).to eq("de")
      expect(described_class.language_to_locale("spanish")).to eq("es")
    end

    it "returns input for unknown languages" do
      expect(described_class.language_to_locale("klingon")).to eq("klingon")
      expect(described_class.language_to_locale("unknown")).to eq("unknown")
    end
  end

  describe ".supported_locales" do
    it "returns array of supported locale codes" do
      locales = described_class.supported_locales
      expect(locales).to be_an(Array)
      expect(locales).to include("fr", "en", "es", "de", "it")
      expect(locales.length).to eq(described_class::LANGUAGES.size)
    end
  end

  describe ".supported_languages" do
    it "returns array of supported language names" do
      languages = described_class.supported_languages
      expect(languages).to be_an(Array)
      expect(languages).to include("français", "english", "español")
      expect(languages.length).to eq(described_class::LANGUAGES.size)
    end
  end

  describe ".locale_supported?" do
    it "returns true for supported locales" do
      expect(described_class.locale_supported?("fr")).to be true
      expect(described_class.locale_supported?("en")).to be true
      expect(described_class.locale_supported?("ja")).to be true
    end

    it "returns false for unsupported locales" do
      expect(described_class.locale_supported?("xx")).to be false
      expect(described_class.locale_supported?("klingon")).to be false
    end

    it "normalizes locales before checking" do
      expect(described_class.locale_supported?("fr-FR")).to be true
      expect(described_class.locale_supported?("en_US")).to be true
      expect(described_class.locale_supported?("FR")).to be true
    end
  end

  describe ".validate_locale!" do
    it "returns normalized locale for supported locales" do
      expect(described_class.validate_locale!("fr")).to eq("fr")
      expect(described_class.validate_locale!("fr-FR")).to eq("fr")
      expect(described_class.validate_locale!("EN_us")).to eq("en")
    end

    it "raises UnsupportedLanguageError for unsupported locales" do
      expect { described_class.validate_locale!("xx") }.to raise_error(
        MistralTranslator::UnsupportedLanguageError,
        "Unsupported language: xx"
      )
    end
  end

  describe ".normalize_locale" do
    it "normalizes various locale formats" do
      expect(described_class.normalize_locale("fr-FR")).to eq("fr")
      expect(described_class.normalize_locale("en_US")).to eq("en")
      expect(described_class.normalize_locale("ES-es")).to eq("es")
      expect(described_class.normalize_locale("DE")).to eq("de")
    end

    it "handles symbols" do
      expect(described_class.normalize_locale(:fr)).to eq("fr")
      expect(described_class.normalize_locale(:"en-US")).to eq("en")
    end

    it "handles edge cases" do
      expect(described_class.normalize_locale("")).to eq("")
      expect(described_class.normalize_locale("fr-")).to eq("fr")
      expect(described_class.normalize_locale("-fr")).to eq("")
      expect(described_class.normalize_locale(nil)).to eq("")
    end
  end

  describe ".supported_languages_list" do
    it "returns formatted string of supported languages" do
      list = described_class.supported_languages_list
      expect(list).to be_a(String)
      expect(list).to include("fr (français)")
      expect(list).to include("en (english)")
      expect(list).to include(", ")
    end

    it "includes all supported languages" do
      list = described_class.supported_languages_list
      described_class.supported_locales.each do |locale|
        language = described_class.locale_to_language(locale)
        expect(list).to include("#{locale} (#{language})")
      end
    end
  end

  describe ".prompt_language_name" do
    it "gives the French name followed by the code" do
      expect(described_class.prompt_language_name("en")).to eq("anglais (en)")
      expect(described_class.prompt_language_name("ja-JP")).to eq("japonais (ja)")
    end

    it "falls back to the code for an unknown locale" do
      expect(described_class.prompt_language_name("xx")).to eq("xx")
    end
  end

  describe "language data" do
    it "covers every ISO 639-1 language CLDR names" do
      expect(described_class.supported_locales.size).to be >= 180
      expect(described_class.supported_locales).to include("br", "wo", "ln", "eu", "oc")
    end

    it "keeps the native names of the original languages" do
      expect(described_class::SUPPORTED_LANGUAGES.slice("fr", "en", "de", "mg", "ja")).to eq(
        "fr" => "français", "en" => "english", "de" => "deutsch", "mg" => "malagasy", "ja" => "日本語"
      )
    end

    it "has a French and an English name for every language" do
      described_class::LANGUAGES.each do |code, names|
        expect(names.values_at("fr", "en", "native")).to all(be_a(String).and(satisfy { |name| !name.empty? })),
                                                         "missing name for #{code}"
      end
    end

    it "accepts English names as aliases" do
      expect(described_class.language_to_locale("Breton")).to eq("br")
      expect(described_class.language_to_locale("brezhoneg")).to eq("br")
    end
  end
end

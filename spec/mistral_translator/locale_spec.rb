# frozen_string_literal: true

RSpec.describe MistralTranslator::Locale do
  describe ".parse" do
    it "reads a language code in any case, with - or _" do
      expect(described_class.parse("fr").to_s).to eq("fr")
      expect(described_class.parse("pt_br").to_s).to eq("pt-BR")
      expect(described_class.parse(:"EN-us").to_s).to eq("en-US")
    end

    it "accepts three-letter languages" do
      expect(described_class.parse("haw").to_s).to eq("haw")
      expect(described_class.parse("yue").to_s).to eq("yue")
    end

    it "brings an ISO 639-3 code back to its two-letter code" do
      expect(described_class.parse("hat").to_s).to eq("ht")
      expect(described_class.parse("fra-CA").to_s).to eq("fr-CA")
    end

    it "keeps the script and the region" do
      expect(described_class.parse("zh-hant").to_s).to eq("zh-Hant")
      expect(described_class.parse("zh_Hant_tw").to_s).to eq("zh-Hant-TW")
      expect(described_class.parse("es-419").to_s).to eq("es-419")
      expect(described_class.parse("fr-SN").to_s).to eq("fr-SN")
    end

    it "accepts French, English and native language names" do
      expect(described_class.parse("allemand").to_s).to eq("de")
      expect(described_class.parse(" Haitian Creole ").to_s).to eq("ht")
      expect(described_class.parse("brezhoneg").to_s).to eq("br")
    end

    it "returns a locale unchanged" do
      locale = described_class.parse("pt-BR")
      expect(described_class.parse(locale)).to be(locale)
    end

    it "rejects unknown languages, scripts and regions" do
      ["xx", "pt-XX", "zh-Abcd", "dothraki", "", nil].each do |input|
        expect { described_class.parse(input) }.to raise_error(MistralTranslator::UnsupportedLanguageError)
      end
    end

    it "rejects variants and extensions" do
      %w[ca-ES-valencia de-CH-1996 en-US-u-ca-gregory en-x-private].each do |input|
        expect { described_class.parse(input) }.to raise_error(MistralTranslator::UnsupportedLanguageError)
      end
    end

    it "rejects a name several languages share" do
      expect(described_class.find("konkani")).to be_nil
      expect(described_class.find("kok")).to eq(described_class.new(language: "kok"))
    end
  end

  describe "equality" do
    it "compares locales by their subtags" do
      expect(described_class.parse("pt_BR")).to eq(described_class.parse("pt-br"))
      expect(described_class.parse("pt-BR")).not_to eq(described_class.parse("pt-PT"))
      expect([described_class.parse("fr"), described_class.parse("FR")].uniq.size).to eq(1)
    end
  end

  describe "#prompt_name" do
    it "names the language, then its script and region, then the code" do
      expect(described_class.parse("en").prompt_name).to eq("anglais (en)")
      expect(described_class.parse("pt-BR").prompt_name).to eq("portugais (Brésil) (pt-BR)")
      expect(described_class.parse("zh-Hant-TW").prompt_name)
        .to eq("chinois (sinogrammes traditionnels, Taïwan) (zh-Hant-TW)")
      expect(described_class.parse("haw").prompt_name).to eq("hawaïen (haw)")
    end
  end
end

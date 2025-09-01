# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Mistral API Integration", :vcr do
  before(:each) do
    # Vérifier que la clé API est disponible pour chaque test
    skip "MISTRAL_API_KEY environment variable required for integration tests" unless ENV["MISTRAL_API_KEY"]

    # Vérifier que la clé API fonctionne vraiment
    MistralTranslator.reset_configuration!
    MistralTranslator.configure do |config|
      config.api_key = ENV["MISTRAL_API_KEY"]
      config.retry_delays = [1, 2] # Retry plus rapides pour les tests
    end

    # Test de connexion rapide
    health = MistralTranslator.health_check
    skip "API connection failed: #{health[:message]}" unless health[:status] == :ok
  end

  after(:each) do
    # Nettoyer la configuration après chaque test
    MistralTranslator.reset_configuration!
  end

  describe "Translation workflow", vcr: { cassette_name: "translation_workflow" } do
    it "performs a complete translation workflow" do
      # Test de traduction simple
      result = MistralTranslator.translate("Bonjour le monde", from: "fr", to: "en")
      expect(result).to be_a(String)
      expect(result.downcase).to include("hello")

      # Test de traduction inverse
      reverse_result = MistralTranslator.translate(result, from: "en", to: "fr")
      expect(reverse_result).to be_a(String)
      expect(reverse_result.downcase).to include("bonjour")
    end
  end

  describe "Multi-language translation", vcr: { cassette_name: "multi_language_translation" } do
    it "translates to multiple languages" do
      result = MistralTranslator.translate_to_multiple(
        "Hello world",
        from: "en",
        to: %w[fr es]
      )

      expect(result).to be_a(Hash)
      expect(result).to have_key("fr")
      expect(result).to have_key("es")
      expect(result["fr"]).to be_a(String)
      expect(result["es"]).to be_a(String)
    end
  end

  describe "Batch translation", vcr: { cassette_name: "batch_translation" } do
    it "translates multiple texts" do
      texts = ["Hello", "Goodbye", "Thank you"]
      result = MistralTranslator.translate_batch(texts, from: "en", to: "fr")

      expect(result).to be_a(Hash)
      expect(result).to have_key(0)
      expect(result).to have_key(1)
      expect(result).to have_key(2)
      expect(result.values).to all(be_a(String))
    end
  end

  describe "Auto-detection", vcr: { cassette_name: "auto_detection" } do
    it "detects language and translates" do
      result = MistralTranslator.translate_auto("Bonjour", to: "en")

      expect(result).to be_a(String)
      expect(result.downcase).to include("hello")
    end
  end

  describe "Summarization workflow",
           vcr: { cassette_name: "summarization_workflow", allow_unused_http_interactions: true } do
    let(:long_text) do
      "Ruby on Rails est un framework de développement web écrit en Ruby. " \
      "Il suit le paradigme Modèle-Vue-Contrôleur (MVC) et privilégie la convention " \
      "plutôt que la configuration. Rails comprend de nombreux outils pour faciliter " \
      "le développement d'applications web, notamment un ORM appelé Active Record, " \
      "un système de routage flexible, et des générateurs de code. " \
      "Le framework a été créé par David Heinemeier Hansson en 2004 et est " \
      "largement utilisé pour construire des applications web modernes."
    end

    it "summarizes text effectively" do
      result = MistralTranslator.summarize(long_text, language: "fr", max_words: 50)

      expect(result).to be_a(String)
      expect(result.length).to be < long_text.length
      expect(result).to include("Rails")
    end

    it "summarizes and translates simultaneously" do
      result = MistralTranslator.summarize_and_translate(
        long_text,
        from: "fr",
        to: "en",
        max_words: 75
      )

      expect(result).to be_a(String)
      expect(result.length).to be < long_text.length
      expect(result.downcase).to include("rails")
    end

    it "creates tiered summaries" do
      result = MistralTranslator.summarize_tiered(
        long_text,
        language: "fr",
        short: 25,
        medium: 75,
        long: 150
      )

      expect(result).to have_key(:short)
      expect(result).to have_key(:medium)
      expect(result).to have_key(:long)

      # Vérifier la progression des longueurs
      expect(result[:short].length).to be < result[:medium].length
      expect(result[:medium].length).to be < result[:long].length
    end
  end

  describe "Error handling" do
    it "handles invalid API key gracefully" do
      # Ce test doit être exécuté avec VCR pour enregistrer la vraie erreur d'API
      # Nous utilisons une cassette VCR qui permettra d'enregistrer l'erreur 401
      VCR.use_cassette("error_handling", record: :new_episodes) do
        # Sauvegarder la configuration actuelle
        original_api_key = MistralTranslator.configuration.api_key

        begin
          # Configurer une clé API invalide
          MistralTranslator.configure { |c| c.api_key = "invalid_key" }

          # S'assurer que la configuration a été appliquée
          expect(MistralTranslator.configuration.api_key).to eq("invalid_key")

          # Le test doit lever une erreur d'authentification
          expect { MistralTranslator.translate("Hello", from: "en", to: "fr") }.to raise_error(
            MistralTranslator::AuthenticationError
          )
        ensure
          # Restaurer la configuration originale
          MistralTranslator.configure { |c| c.api_key = original_api_key }
        end
      end
    end
  end

  describe "Health check", vcr: { cassette_name: "health_check" } do
    it "validates API connection" do
      # Réinitialiser avec une bonne clé pour le health check
      MistralTranslator.configure do |config|
        config.api_key = ENV["MISTRAL_API_KEY"] || "test_api_key"
      end

      result = MistralTranslator.health_check

      if ENV["MISTRAL_API_KEY"]
        expect(result[:status]).to eq(:ok)
        expect(result[:message]).to eq("API connection successful")
      else
        # En mode test sans vraie clé
        expect(result[:status]).to eq(:error)
      end
    end
  end

  describe "Supported languages verification" do
    it "lists all supported languages" do
      languages = MistralTranslator.supported_languages
      expect(languages).to include("fr (français)")
      expect(languages).to include("en (english)")
      expect(languages).to include("es (español)")
    end

    it "validates locale support correctly" do
      expect(MistralTranslator.locale_supported?("fr")).to be true
      expect(MistralTranslator.locale_supported?("en")).to be true
      expect(MistralTranslator.locale_supported?("klingon")).to be false
    end
  end
end

# frozen_string_literal: true

# require "spec_helper"

RSpec.describe "Mistral API Integration", :vcr do
  before do
    # Utiliser votre helper existant pour vérifier la disponibilité de l'API
    unless ApiKeyHelper.real_api_available?
      puts "\n⚠️  Skipping integration tests - no real API key found"
      puts "   Set MISTRAL_TEST_API_KEY or MISTRAL_API_KEY environment variable to run real API tests"
      puts "   Example: export MISTRAL_TEST_API_KEY=your_api_key_here"
      skip "Real API key required for integration tests"
    end

    # Setup initial avec votre helper
    VCRHelper.setup_real_api_tests?
    MistralTranslator.reset_configuration!
    ApiKeyHelper.setup_test_configuration!

    # Ajuster la configuration pour les tests d'intégration
    MistralTranslator.configure do |config|
      config.enable_metrics = true
      config.retry_delays = [1, 2] # Un peu plus lent que les tests unitaires
    end

    # Validation rapide de la clé API
    health = MistralTranslator.health_check
    if health[:status] != :ok
      puts "\n❌ API connection failed: #{health[:message]}"
      skip "API connection failed: #{health[:message]}"
    end
  end

  after do
    # Nettoyer après chaque test
    MistralTranslator.reset_configuration!
    MistralTranslator.reset_metrics!
  end

  describe "Basic Translation Workflow", vcr: { cassette_name: "basic_translation" } do
    it "performs simple translation" do
      result = MistralTranslator.translate("Bonjour le monde", from: "fr", to: "en")

      expect(result).to be_a(String)
      expect(result.downcase).to include("hello")
      expect(result.length).to be > 5
    end

    it "handles empty text gracefully" do
      result = MistralTranslator.translate("", from: "fr", to: "en")
      expect(result).to eq("")
    end

    it "validates language codes" do
      expect do
        MistralTranslator.translate("Hello", from: "invalid", to: "fr")
      end.to raise_error(MistralTranslator::UnsupportedLanguageError)
    end
  end

  describe "Translation with Context and Glossary", vcr: { cassette_name: "contextual_translation" } do
    it "translates with technical context" do
      text = "The API endpoint returns a JSON response"
      context = "software development documentation"
      glossary = { "API" => "API", "endpoint" => "point de terminaison" }

      result = MistralTranslator.translate(
        text,
        from: "en",
        to: "fr",
        context: context,
        glossary: glossary
      )

      expect(result).to be_a(String)
      expect(result.downcase).to include("api")
      expect(result.length).to be > 10
    end

    it "respects glossary terms" do
      text = "The user interface is intuitive"
      glossary = { "interface" => "interface utilisateur" }

      result = MistralTranslator.translate(
        text,
        from: "en",
        to: "fr",
        glossary: glossary
      )

      expect(result).to be_a(String)
      expect(result.length).to be > 5

      # Vérifier que la traduction contient soit "interface" soit "utilisateur"
      # (le glossaire devrait influencer la traduction)
      result_lower = result.downcase
      expect(result_lower).to match(/interface|utilisateur|intuitive/)
    end
  end

  describe "Multi-language Translation", vcr: { cassette_name: "multi_language" } do
    it "translates to multiple target languages" do
      result = MistralTranslator.translate_to_multiple(
        "Hello world",
        from: "en",
        to: %w[fr es de]
      )

      expect(result).to be_a(Hash)
      expect(result).to have_key("fr")
      expect(result).to have_key("es")
      expect(result).to have_key("de")

      result.each_value do |translation|
        expect(translation).to be_a(String)
        expect(translation.length).to be > 3
      end
    end

    it "handles single target language as string" do
      result = MistralTranslator.translate_to_multiple(
        "Good morning",
        from: "en",
        to: "fr"
      )

      expect(result).to be_a(Hash)
      expect(result).to have_key("fr")
      expect(result["fr"]).to be_a(String)
      expect(result["fr"].downcase).to include("bonjour")
    end
  end

  describe "Batch Translation", vcr: { cassette_name: "batch_translation" } do
    it "translates multiple texts efficiently" do
      texts = [
        "Good morning",
        "Good afternoon",
        "Good evening",
        "Good night"
      ]

      result = MistralTranslator.translate_batch(texts, from: "en", to: "fr")

      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly(0, 1, 2, 3)

      result.each_value do |translation|
        expect(translation).to be_a(String)
        expect(translation.length).to be > 3
      end

      # Vérifier que certaines traductions contiennent des mots français attendus
      french_words = result.values.join(" ").downcase
      expect(french_words).to match(/bonjour|bonsoir|bonne/)
    end

    it "handles mixed content batch" do
      texts = [
        "Technical documentation",
        "User interface",
        "Database connection"
      ]

      result = MistralTranslator.translate_batch(
        texts,
        from: "en",
        to: "fr",
        context: "software development"
      )

      expect(result).to be_a(Hash)
      expect(result.size).to eq(3)

      result.each_value do |translation|
        expect(translation).to be_a(String)
        expect(translation.length).to be > 5
      end
    end
  end

  describe "Auto Language Detection", vcr: { cassette_name: "auto_detection" } do
    it "detects French and translates to English" do
      result = MistralTranslator.translate_auto("Bonjour le monde", to: "en")

      expect(result).to be_a(String)
      expect(result.downcase).to include("hello")
    end

    it "detects Spanish and translates to French" do
      result = MistralTranslator.translate_auto("Hola mundo", to: "fr")

      expect(result).to be_a(String)
      expect(result.length).to be > 5
    end

    it "handles unknown languages gracefully" do
      # Test avec du texte très court qui pourrait être ambigu
      result = MistralTranslator.translate_auto("Hi", to: "fr")

      expect(result).to be_a(String)
      expect(result.length).to be > 1
    end
  end

  describe "Text Summarization", vcr: { cassette_name: "summarization" } do
    let(:long_text) do
      "Ruby on Rails est un framework de développement web écrit en Ruby qui suit le paradigme " \
        "Modèle-Vue-Contrôleur (MVC) et privilégie la convention plutôt que la configuration. " \
        "Rails comprend de nombreux outils pour faciliter le développement d'applications web, " \
        "notamment un ORM appelé Active Record, un système de routage flexible, et des " \
        "générateurs de code. Le framework a été créé par David Heinemeier Hansson en 2004 " \
        "et continue d'évoluer avec une communauté active de développeurs. Il est largement " \
        "utilisé pour construire des applications web modernes et scalables."
    end

    it "creates effective summaries" do
      result = MistralTranslator.summarize(long_text, language: "fr", max_words: 50)

      expect(result).to be_a(String)
      expect(result.length).to be < long_text.length
      expect(result.downcase).to include("rails")

      # Vérifier que le résumé n'est pas juste une troncature
      expect(result).not_to eq(long_text[0...result.length])
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
      expect(result.downcase).to include("framework")
    end

    it "creates tiered summaries with different lengths" do
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

      # Vérifier la progression des longueurs (approximative)
      # L'API peut ne pas respecter exactement les limites, donc on vérifie une tendance générale
      expect(result[:short].length).to be < result[:long].length
      expect(result[:medium].length).to be < result[:long].length

      # Tous doivent contenir des informations pertinentes
      [result[:short], result[:medium], result[:long]].each do |summary|
        expect(summary.downcase).to include("rails")
      end
    end

    it "summarizes to multiple languages" do
      result = MistralTranslator.summarize_to_multiple(
        long_text,
        languages: %w[fr en es],
        max_words: 100
      )

      expect(result).to be_a(Hash)
      expect(result).to have_key("fr")
      expect(result).to have_key("en")
      expect(result).to have_key("es")

      result.each_value do |summary|
        expect(summary).to be_a(String)
        expect(summary.length).to be < long_text.length
        expect(summary.length).to be > 20
      end
    end
  end

  describe "Advanced Features", vcr: { cassette_name: "advanced_features" } do
    it "handles HTML content translation" do
      html_content = "<p>Hello <strong>world</strong></p>"

      result = MistralTranslator::Helpers.translate_rich_text(
        html_content,
        from: "en",
        to: "fr"
      )

      expect(result).to be_a(String)
      expect(result).to include("<p>")
      expect(result).to include("<strong>")
      expect(result).to include("</strong>")
      expect(result).to include("</p>")
    end

    it "provides translation with quality check" do
      result = MistralTranslator::Helpers.translate_with_quality_check(
        "Hello world",
        from: "en",
        to: "fr"
      )

      expect(result).to have_key(:translation)
      expect(result).to have_key(:quality_check)
      expect(result).to have_key(:metadata)

      expect(result[:translation]).to be_a(String)
      expect(result[:quality_check]).to be_a(Hash)
    end

    it "estimates translation costs" do
      text = "This is a sample text for cost estimation testing purposes."

      result = MistralTranslator::Helpers.estimate_translation_cost(
        text,
        from: "en",
        to: "fr",
        rate_per_1k_chars: 0.02
      )

      expect(result).to have_key(:character_count)
      expect(result).to have_key(:estimated_cost)
      expect(result).to have_key(:currency)

      expect(result[:character_count]).to eq(text.length)
      expect(result[:estimated_cost]).to be_a(Float)
      expect(result[:currency]).to eq("USD")
    end
  end

  describe "Error Handling and Edge Cases", vcr: { cassette_name: "error_handling" } do
    it "handles rate limiting gracefully" do
      # Ce test pourrait déclencher un rate limit selon votre usage
      texts = (1..5).map { |i| "Test message number #{i}" }

      expect do
        results = texts.map do |text|
          MistralTranslator.translate(text, from: "en", to: "fr")
          sleep(0.5) # Petite pause pour éviter le rate limiting
        end
        expect(results.size).to eq(5)
      end.not_to raise_error
    end

    it "handles same source and target language" do
      result = MistralTranslator.translate("Hello", from: "en", to: "en")
      expect(result).to eq("Hello")
    end

    it "handles unsupported languages" do
      expect do
        MistralTranslator.translate("Hello", from: "klingon", to: "fr")
      end.to raise_error(MistralTranslator::UnsupportedLanguageError)
    end
  end

  describe "Metrics and Monitoring", vcr: { cassette_name: "metrics" } do
    before do
      # Forcer le reset des métriques avant chaque test
      MistralTranslator.reset_metrics!
      MistralTranslator.configure { |c| c.enable_metrics = true }
    end

    it "tracks translation metrics" do
      # Effectuer quelques traductions
      MistralTranslator.translate("Hello", from: "en", to: "fr")
      MistralTranslator.translate("World", from: "en", to: "es")

      metrics = MistralTranslator.metrics

      expect(metrics[:total_translations]).to be >= 2
      expect(metrics[:total_characters]).to be > 0
      expect(metrics[:translations_by_language]).to have_key("en->fr")
      expect(metrics[:translations_by_language]).to have_key("en->es")
      expect(metrics[:average_translation_time]).to be >= 0
    end

    it "provides meaningful performance metrics" do
      # Sauvegarder les métriques existantes
      initial_metrics = MistralTranslator.metrics
      initial_translations = initial_metrics[:total_translations] || 0
      initial_characters = initial_metrics[:total_characters] || 0

      start_time = Time.now

      # Traduction plus longue pour des métriques significatives
      long_text = "This is a longer text that should provide better metrics for testing purposes."
      result = MistralTranslator.translate(long_text, from: "en", to: "fr")

      end_time = Time.now
      duration = end_time - start_time

      expect(result).to be_a(String)
      expect(duration).to be > 0

      metrics = MistralTranslator.metrics
      expect(metrics[:total_translations]).to be >= initial_translations + 1
      expect(metrics[:average_translation_time]).to be >= 0

      # Vérifier que les caractères ont été ajoutés correctement
      expect(metrics[:total_characters]).to be >= initial_characters + long_text.length

      # Vérifier que la moyenne est cohérente
      if metrics[:total_translations] > 0
        expected_avg = metrics[:total_characters] / metrics[:total_translations]
        expect(metrics[:average_characters_per_translation]).to eq(expected_avg)
      end
    end
  end

  describe "Health Check and Diagnostics", vcr: { cassette_name: "health_check" } do
    it "validates API connectivity" do
      health = MistralTranslator.health_check

      expect(health[:status]).to eq(:ok)
      expect(health[:message]).to eq("API connection successful")
    end

    it "provides system information" do
      version_info = MistralTranslator.version_info

      expect(version_info).to have_key(:gem_version)
      expect(version_info).to have_key(:api_version)
      expect(version_info).to have_key(:supported_model)
      expect(version_info).to have_key(:ruby_version)
      expect(version_info).to have_key(:platform)

      expect(version_info[:gem_version]).to eq(MistralTranslator::VERSION)
    end

    it "lists supported languages correctly" do
      languages = MistralTranslator.supported_languages
      locales = MistralTranslator.supported_locales

      expect(languages).to be_a(String)
      expect(languages).to include("fr (français)")
      expect(languages).to include("en (english)")

      expect(locales).to be_an(Array)
      expect(locales).to include("fr", "en", "es", "de", "it")
    end
  end
end

# Tests spécifiques pour les cas de production
RSpec.describe "Production Scenarios", :vcr do
  before do
    skip "MISTRAL_API_KEY environment variable required for production scenario tests" unless ENV["MISTRAL_API_KEY"]
    MistralTranslator.reset_configuration!
    MistralTranslator.configure do |config|
      config.api_key = ENV.fetch("MISTRAL_API_KEY")
      config.enable_metrics = true
      config.retry_delays = [1, 2, 4] # Configuration production-like
    end
  end

  describe "Real-world Content", vcr: { cassette_name: "real_world_content" } do
    it "handles technical documentation" do
      tech_content = <<~TEXT
        Cette API REST permet de gérer les utilisateurs et leurs permissions.
        Les endpoints disponibles incluent GET /users pour lister les utilisateurs,
        POST /users pour créer un nouveau compte, et DELETE /users/:id pour#{" "}
        supprimer un utilisateur existant. Toutes les requêtes doivent inclure
        un token d'authentification dans l'en-tête Authorization.
      TEXT

      result = MistralTranslator.translate(
        tech_content,
        from: "fr",
        to: "en",
        context: "API documentation"
      )

      expect(result).to be_a(String)
      expect(result).to include("API")
      expect(result).to include("users")
      expect(result).to include("authentication")
      expect(result.length).to be > 100
    end

    it "handles marketing content" do
      marketing_content = <<~TEXT
        Découvrez notre nouvelle solution cloud qui révolutionne la collaboration
        en équipe. Avec des fonctionnalités avancées de partage de fichiers,
        de messagerie instantanée et de vidéoconférence, votre productivité
        atteindra de nouveaux sommets. Essai gratuit de 30 jours inclus !
      TEXT

      result = MistralTranslator.translate(
        marketing_content,
        from: "fr",
        to: "en",
        context: "marketing copy"
      )

      expect(result).to be_a(String)
      expect(result.length).to be > 100

      # Vérifier que la traduction contient des mots-clés marketing
      result_lower = result.downcase
      expect(result_lower).to match(/cloud|team|collaboration|productivity|trial|solution/)
    end

    it "handles user interface text" do
      ui_texts = [
        "Enregistrer les modifications",
        "Annuler l'opération",
        "Confirmer la suppression",
        "Paramètres avancés",
        "Aide et support"
      ]

      result = MistralTranslator.translate_batch(
        ui_texts,
        from: "fr",
        to: "en",
        context: "user interface"
      )

      expect(result).to be_a(Hash)
      expect(result.size).to eq(5)

      result.each_value do |translation|
        expect(translation).to be_a(String)
        expect(translation.length).to be > 3
      end

      # Vérifier que les traductions contiennent des mots-clés UI appropriés
      translations = result.values.join(" ").downcase
      expect(translations).to match(/save|cancel|delete|settings|help|support|modify|operation|confirm/)
    end
  end

  describe "Performance and Scalability", vcr: { cassette_name: "performance" } do
    it "handles concurrent-like operations efficiently" do
      start_time = Time.now

      # Simuler des opérations concurrentes avec du batch
      batch1 = ["Premier message", "Deuxième message", "Troisième message"]
      batch2 = ["Quatrième message", "Cinquième message", "Sixième message"]

      result1 = MistralTranslator.translate_batch(batch1, from: "fr", to: "en")
      result2 = MistralTranslator.translate_batch(batch2, from: "fr", to: "en")

      end_time = Time.now
      total_duration = end_time - start_time

      expect(result1.size).to eq(3)
      expect(result2.size).to eq(3)
      expect(total_duration).to be < 30 # Moins de 30 secondes pour 6 traductions

      # Vérifier les métriques
      metrics = MistralTranslator.metrics
      expect(metrics[:total_translations]).to be >= 6
    end

    it "maintains quality with varied content types" do
      mixed_content = {
        technical: "Configuration du serveur de base de données",
        formal: "Nous vous prions de bien vouloir confirmer votre présence",
        casual: "Salut ! Comment ça va aujourd'hui ?",
        numeric: "Le prix est de 25,99 euros TTC"
      }

      results = {}
      mixed_content.each do |type, text|
        results[type] = MistralTranslator.translate(
          text,
          from: "fr",
          to: "en",
          context: type.to_s
        )
      end

      expect(results).to have_key(:technical)
      expect(results).to have_key(:formal)
      expect(results).to have_key(:casual)
      expect(results).to have_key(:numeric)

      # Vérifier que chaque type a été traduit de manière appropriée
      expect(results[:technical].downcase).to match(/database|server|configuration|technical/)
      expect(results[:formal].downcase).to match(/please|confirm|presence|formal/)
      expect(results[:casual].downcase).to match(/hi|hello|how|today|casual/)
      expect(results[:numeric].downcase).to match(/25|99|price|euro|cost/)
    end
  end
end

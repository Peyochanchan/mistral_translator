# frozen_string_literal: true

# Helper pour configurer VCR dans les tests d'intégration
module VCRHelper
  def self.setup_real_api_tests?
    if ENV["MISTRAL_API_KEY"]
      # puts "🔑 Clé API détectée - Tests d'intégration avec vraie API"
      MistralTranslator.configure do |config|
        config.api_key = ENV["MISTRAL_API_KEY"]
      end
      true
    else
      # puts "⚠️  Pas de clé API - Tests d'intégration skippés"
      puts "   Définissez MISTRAL_API_KEY pour tester avec la vraie API"
      false
    end
  end

  def self.create_vcr_cassette(name)
    VCR.use_cassette(name) do
      yield if block_given?
    end
  end
end

RSpec.configure do |config|
  config.before(:each, :real_api) do
    skip "Pas de clé API définie" unless ENV["MISTRAL_API_KEY"]
  end

  # Configuration pour les tests VCR
  config.before(:each, :vcr) do
    # Configuration spécifique pour VCR si nécessaire
  end
end

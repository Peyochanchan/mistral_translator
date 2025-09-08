# frozen_string_literal: true

# spec/support/api_key_helper.rb

module ApiKeyHelper
  FAKE_API_KEY = "test_mistral_key_abcdef123456789"

  def self.test_api_key
    ENV["MISTRAL_TEST_API_KEY"] || ENV["MISTRAL_API_KEY"] || FAKE_API_KEY
  end

  def self.real_api_available?
    !!(ENV["MISTRAL_TEST_API_KEY"] || ENV.fetch("MISTRAL_API_KEY", nil))
  end

  def self.setup_test_configuration!
    MistralTranslator.configure do |config|
      config.api_key = test_api_key
      config.api_url = "https://api.mistral.ai"
      config.retry_delays = [0.1, 0.2]
    end
  end
end

module VCRHelper
  def self.setup_real_api_tests?
    if ApiKeyHelper.real_api_available?
      # puts "🔑 Clé API détectée - Tests d'intégration avec vraie API"
      ApiKeyHelper.setup_test_configuration!
      true
    else
      puts "⚠️  Pas de clé API - Tests d'intégration skippés"
      puts "   Définissez MISTRAL_TEST_API_KEY pour tester avec la vraie API"
      false
    end
  end

  def self.create_vcr_cassette(name)
    VCR.use_cassette(name) do
      yield if block_given?
    end
  end
end

# frozen_string_literal: true

require "mistral_translator"
require "webmock/rspec"
require "vcr"

# Configuration VCR pour enregistrer les appels API
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = {
    record: :once,
    allow_unused_http_interactions: false
  }

  # Masquer les clés API dans les enregistrements
  config.filter_sensitive_data("<MISTRAL_API_KEY>") { ENV["MISTRAL_API_KEY"] }
  config.filter_sensitive_data("<MISTRAL_API_KEY>") do |interaction|
    auth_header = interaction.request.headers["Authorization"]&.first
    auth_header.split(" ", 2).last if auth_header&.start_with?("Bearer ")
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Configuration WebMock
  config.before(:each) do
    WebMock.reset!
    MistralTranslator.reset_configuration!

    # Configuration par défaut pour les tests
    MistralTranslator.configure do |c|
      c.api_key = "test_api_key"
      c.api_url = "https://api.mistral.ai"
      c.retry_delays = [0.1, 0.2] # Retry plus rapides pour les tests
    end
  end

  # Permettre les connexions réseau pour les tests d'intégration
  config.before(:each, :integration) do
    WebMock.allow_net_connect!
  end

  config.after(:each, :integration) do
    WebMock.disable_net_connect!
  end

  # Helpers pour les tests
  config.include(Module.new do
    def stub_mistral_api(response_body:, status: 200)
      # Si response_body est déjà une chaîne, on l'utilise directement
      # Sinon on la convertit en JSON
      body = response_body.is_a?(String) ? response_body : response_body.to_json

      stub_request(:post, "https://api.mistral.ai/v1/chat/completions")
        .to_return(
          status: status,
          body: body,
          headers: { "Content-Type" => "application/json" }
        )
    end

    def valid_translation_response(original: "Hello", translated: "Bonjour")
      {
        choices: [
          {
            message: {
              content: {
                content: {
                  source: original,
                  target: translated
                },
                metadata: {
                  source: "en",
                  target: "fr"
                }
              }.to_json
            }
          }
        ]
      }
    end

    def valid_summary_response(original: "Long text", summary: "Short summary")
      {
        choices: [
          {
            message: {
              content: {
                content: {
                  source: original,
                  target: summary
                },
                metadata: {
                  source: "original",
                  target: "summary"
                }
              }.to_json
            }
          }
        ]
      }
    end

    def rate_limit_response
      {
        error: {
          message: "rate limit exceeded",
          type: "rate_limit_error"
        }
      }
    end

    def invalid_api_key_response
      {
        error: {
          message: "Invalid API key",
          type: "authentication_error"
        }
      }
    end
  end)
end

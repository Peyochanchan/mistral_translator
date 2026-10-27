# frozen_string_literal: true

require "mistral_translator"
require "webmock/rspec"
require "vcr"

# Charger vos helpers existants
require_relative "support/api_key_helper"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Configuration pour les tests d'intégration avec gestion flexible
  config.default_cassette_options = {
    record: :new_episodes, # Permet d'enregistrer de nouvelles interactions
    allow_unused_http_interactions: true,
    match_requests_on: %i[method uri body] # Match sur le body pour éviter les réponses incorrectes
  }

  # Masquer les clés API dans les enregistrements avec votre helper
  config.filter_sensitive_data("<MISTRAL_API_KEY>") do
    ApiKeyHelper.test_api_key if ApiKeyHelper.real_api_available?
  end

  config.filter_sensitive_data("<MISTRAL_API_KEY>") do |interaction|
    auth_header = interaction.request.headers["Authorization"]&.first
    auth_header.split(" ", 2).last if auth_header&.start_with?("Bearer ")
  end

  # Filtrer autres données sensibles
  config.filter_sensitive_data("<REQUEST_ID>") do |interaction|
    interaction.response.headers["X-Kong-Request-Id"]&.first
  end

  config.filter_sensitive_data("<CORRELATION_ID>") do |interaction|
    interaction.response.headers["Mistral-Correlation-Id"]&.first
  end

  # Filtrer les données de rate limiting
  config.filter_sensitive_data("<RATE_LIMIT_REMAINING>") do |interaction|
    interaction.response.headers["X-Ratelimit-Remaining-Tokens-Minute"]&.first
  end

  config.filter_sensitive_data("<RATE_LIMIT_MONTH>") do |interaction|
    interaction.response.headers["X-Ratelimit-Remaining-Tokens-Month"]&.first
  end

  # Filtrer les cookies de session
  config.filter_sensitive_data("<CF_BM_COOKIE>") do |interaction|
    cookies = interaction.response.headers["Set-Cookie"]
    if cookies
      cf_bm = cookies.find { |cookie| cookie.include?("__cf_bm=") }
      cf_bm_value = cf_bm&.split("__cf_bm=", 2)&.last
      cf_bm_value&.split(";")&.first
    end
  end

  # Filtrer les informations de géolocalisation
  config.filter_sensitive_data("<CF_RAY>") do |interaction|
    interaction.response.headers["Cf-Ray"]&.first
  end

  # Filtrer les IDs de requête Cloudflare
  config.filter_sensitive_data("<CF_REQUEST_ID>") do |interaction|
    interaction.response.headers["Cf-Request-Id"]&.first
  end

  # Empêcher l'enregistrement avec des clés factices
  config.before_record do |interaction|
    auth_header = interaction.request.headers["Authorization"]&.first

    if auth_header&.include?(ApiKeyHelper::FAKE_API_KEY)
      raise "Attempted to record VCR cassette with fake API key! Use a real API key for recording."
    end
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
  config.before do
    WebMock.reset!
    MistralTranslator.reset_configuration!

    # Configuration par défaut pour les tests unitaires en utilisant votre helper
    ApiKeyHelper.setup_test_configuration!

    # Mock des constantes Rails/ActiveRecord si elles ne sont pas définies
    unless defined?(ActiveRecord::Base)
      ar_mock = double("ActiveRecord::Base")
      allow(ar_mock).to receive(:transaction).and_yield
      stub_const("ActiveRecord::Base", ar_mock)
    end

    unless defined?(Rails)
      rails_mock = double("Rails")
      logger_mock = double("Logger")
      allow(logger_mock).to receive(:warn)
      allow(logger_mock).to receive(:error)
      allow(logger_mock).to receive(:info)
      allow(rails_mock).to receive(:logger).and_return(logger_mock)
      stub_const("Rails", rails_mock)
    end

    # Mock I18n si pas défini
    unless defined?(I18n)
      i18n_mock = double("I18n")
      allow(i18n_mock).to receive(:available_locales).and_return(%i[fr en es])
      allow(i18n_mock).to receive(:with_locale).and_yield
      stub_const("I18n", i18n_mock)
    end
  end

  # Afficher les informations sur les tests d'intégration au début
  config.before(:suite) do
    # Never print any part of the key: it would end up in terminals and CI logs.
    if ApiKeyHelper.real_api_available?
      puts "🔑 Real Mistral API key detected: VCR cassettes can be recorded"
    else
      puts "⚠️  No real API key - integration tests will be skipped"
      puts "   Set MISTRAL_TEST_API_KEY or MISTRAL_API_KEY to run integration tests"
    end
  end

  # Configuration pour les tests d'intégration
  config.before(:each, :integration) do
    skip "Real API key required for integration tests" unless ApiKeyHelper.real_api_available?
    WebMock.allow_net_connect!
  end

  config.after(:each, :integration) do
    WebMock.disable_net_connect!
  end

  # Configuration pour les tests VCR
  # With a key, the examples run against the real API and record cassettes
  # (bin/check_api, and the weekly workflow). Cassettes are not
  # committed: without a key, an existing local recording is replayed, and the
  # examples are skipped otherwise.
  config.around(:each, :vcr) do |example|
    cassette_name = example.metadata[:cassette_name] ||
                    generate_cassette_name_from_example(example)

    if ApiKeyHelper.real_api_available?
      # Spaces out the calls: the free API plan allows about one request per second.
      sleep(Float(ENV.fetch("VCR_RECORD_PAUSE", "1.5")))
      VCR.use_cassette(cassette_name) { example.run }
    elsif File.exist?(VCR::Cassette.new(cassette_name).file)
      VCR.use_cassette(cassette_name, record: :none) { example.run }
    else
      skip "Real API key required (bin/check_api)"
    end
  end

  # Helpers pour les tests
  config.include(Module.new do
    def stub_mistral_api(response_body: nil, status: 200)
      # Réponse par défaut si aucune fournie
      default_response = {
        choices: [
          {
            message: {
              content: {
                content: {
                  source: "Hello",
                  target: "Bonjour"
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

      # Si response_body est déjà une chaîne, on l'utilise directement
      # Sinon on la convertit en JSON
      body = response_body.is_a?(String) ? response_body : (response_body || default_response).to_json

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

    private

    def generate_cassette_name_from_example(example)
      description = example.metadata[:description_args].join("_")
      description.gsub(/\W+/, "_").downcase
    end
  end)
end

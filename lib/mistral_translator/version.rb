# frozen_string_literal: true

module MistralTranslator
  VERSION = "0.2.1"

  # Informations additionnelles sur la gem
  API_VERSION = "v1"
  SUPPORTED_MODEL = "mistral-small"

  # Méthode pour obtenir des informations complètes sur la version
  def self.version_info
    {
      gem_version: VERSION,
      api_version: API_VERSION,
      supported_model: SUPPORTED_MODEL,
      ruby_version: RUBY_VERSION,
      platform: RUBY_PLATFORM
    }
  end
end

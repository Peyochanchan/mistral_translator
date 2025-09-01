# frozen_string_literal: true

module MistralTranslator
  class Configuration
    attr_accessor :api_key, :api_url, :model, :default_max_tokens, :default_temperature, :retry_delays

    def initialize
      @api_key = nil
      @api_url = "https://api.mistral.ai"
      @model = "mistral-small"
      @default_max_tokens = nil
      @default_temperature = nil
      @retry_delays = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]
    end

    def api_key!
      if @api_key.nil?
        raise ConfigurationError,
              "API key is required. Set it with MistralTranslator.configure { |c| c.api_key = 'your_key' }"
      end

      @api_key
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

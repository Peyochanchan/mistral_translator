# frozen_string_literal: true

module MistralTranslator
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class ApiError < Error
    attr_reader :response, :status_code

    def initialize(message, response = nil, status_code = nil)
      super(message)
      @response = response
      @status_code = status_code
    end
  end

  class RateLimitError < ApiError
    def initialize(message = "API rate limit exceeded", response = nil, status_code = 429)
      super
    end
  end

  class AuthenticationError < ApiError
    def initialize(message = "Invalid API key", response = nil, status_code = 401)
      super
    end
  end

  class InvalidResponseError < Error
    attr_reader :raw_response

    def initialize(message, raw_response = nil)
      super(message)
      @raw_response = raw_response
    end
  end

  class EmptyTranslationError < Error
    def initialize(message = "Empty translation received from API")
      super
    end
  end

  class UnsupportedLanguageError < Error
    attr_reader :language

    def initialize(language)
      @language = language
      super("Unsupported language: #{language}")
    end
  end

  class SecurityError < Error
    def initialize(message = "Security violation detected")
      super
    end
  end

  class RateLimitExceededError < Error
    attr_reader :wait_time, :retry_after

    def initialize(message = "Rate limit exceeded", wait_time: nil, retry_after: nil)
      super(message)
      @wait_time = wait_time
      @retry_after = retry_after
    end
  end
end

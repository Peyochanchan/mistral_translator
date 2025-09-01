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
      super(message, response, status_code)
    end
  end
  
  class AuthenticationError < ApiError
    def initialize(message = "Invalid API key", response = nil, status_code = 401)
      super(message, response, status_code)
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
      super(message)
    end
  end
  
  class UnsupportedLanguageError < Error
    attr_reader :language
    
    def initialize(language)
      @language = language
      super("Unsupported language: #{language}")
    end
  end
end
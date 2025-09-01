# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module MistralTranslator
  class Client
    def initialize(api_key: nil)
      @api_key = api_key || MistralTranslator.configuration.api_key!
      @base_uri = MistralTranslator.configuration.api_url
      @model = MistralTranslator.configuration.model
      @retry_delays = MistralTranslator.configuration.retry_delays
    end

    def complete(prompt, max_tokens: nil, temperature: nil)
      response = make_request_with_retry(prompt, max_tokens, temperature)
      parsed_response = JSON.parse(response.body)

      content = parsed_response.dig("choices", 0, "message", "content")
      raise InvalidResponseError, "No content in API response" if content.nil? || content.empty?

      content
    rescue JSON::ParserError => e
      raise InvalidResponseError, "Invalid JSON in API response: #{e.message}"
    end

    def chat(prompt, max_tokens: nil, temperature: nil)
      response = make_request_with_retry(prompt, max_tokens, temperature)
      parsed_response = JSON.parse(response.body)

      parsed_response.dig("choices", 0, "message", "content")
    rescue JSON::ParserError => e
      raise InvalidResponseError, "JSON parse error: #{e.message}"
    end

    private

    def make_request_with_retry(prompt, max_tokens, temperature, attempt = 0)
      response = make_request(prompt, max_tokens, temperature)

      # Vérifier les erreurs dans la réponse
      check_response_for_errors(response)

      if rate_limit_exceeded?(response)
        handle_rate_limit(prompt, max_tokens, temperature, attempt)
      else
        response
      end
    end

    def make_request(prompt, max_tokens, temperature)
      uri = URI("#{@base_uri}/v1/chat/completions")

      request_body = build_request_body(prompt, max_tokens, temperature)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.read_timeout = 60 # 60 secondes de timeout

      request = Net::HTTP::Post.new(uri.path, headers)
      request.body = request_body.to_json

      response = http.request(request)
      log_request_response(request_body, response)

      response
    rescue Net::TimeoutError => e
      raise ApiError, "Request timeout: #{e.message}"
    rescue Net::HTTPError => e
      raise ApiError, "HTTP error: #{e.message}"
    end

    def build_request_body(prompt, max_tokens, temperature)
      body = {
        model: @model,
        messages: [{ role: "user", content: prompt }]
      }

      body[:max_tokens] = max_tokens if max_tokens
      body[:temperature] = temperature if temperature

      body
    end

    def headers
      {
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type" => "application/json",
        "User-Agent" => "mistral-translator-gem/#{MistralTranslator::VERSION}"
      }
    end

    def check_response_for_errors(response)
      case response.code.to_i
      when 401
        raise AuthenticationError, "Invalid API key"
      when 429
        # Rate limit sera géré séparément
        nil
      when 400..499
        raise ApiError, "Client error (#{response.code}): #{response.body}"
      when 500..599
        raise ApiError, "Server error (#{response.code}): #{response.body}"
      end
    end

    def rate_limit_exceeded?(response)
      response.code.to_i == 429 || response.body.include?("rate limit exceeded")
    end

    def handle_rate_limit(prompt, max_tokens, temperature, attempt)
      unless attempt < @retry_delays.length
        raise RateLimitError, "API rate limit exceeded after #{@retry_delays.length} retries"
      end

      wait_time = @retry_delays[attempt]
      log_rate_limit_retry(wait_time, attempt)
      sleep(wait_time)
      make_request_with_retry(prompt, max_tokens, temperature, attempt + 1)
    end

    def log_request_response(request_body, response)
      return unless defined?(Rails) && Rails.respond_to?(:logger)

      Rails.logger.info "[MistralTranslator] Request: #{request_body.to_json}"
      Rails.logger.info "[MistralTranslator] Response (#{response.code}): #{response.body}"
    end

    def log_rate_limit_retry(wait_time, attempt)
      message = "[MistralTranslator] Rate limit exceeded, retrying in #{wait_time} seconds (attempt #{attempt + 1})"

      if defined?(Rails) && Rails.respond_to?(:logger)
        Rails.logger.info message
      else
        puts message
      end
    end
  end
end

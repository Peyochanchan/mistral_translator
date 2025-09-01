# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require_relative "logger"

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
    rescue NoMethodError => e
      raise InvalidResponseError, "Invalid response structure: #{e.message}"
    end

    def chat(prompt, max_tokens: nil, temperature: nil)
      response = make_request_with_retry(prompt, max_tokens, temperature)
      parsed_response = JSON.parse(response.body)

      parsed_response.dig("choices", 0, "message", "content")
    rescue JSON::ParserError => e
      raise InvalidResponseError, "JSON parse error: #{e.message}"
    rescue NoMethodError => e
      raise InvalidResponseError, "Invalid response structure: #{e.message}"
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
    rescue Net::ReadTimeout => e
      raise ApiError, "Request timeout: #{e.message}"
    rescue Net::HTTPError => e
      raise ApiError, "HTTP error: #{e.message}"
    rescue Timeout::Error => e
      raise ApiError, "Request timeout: #{e.message}"
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
        raise ApiError, "Client error (#{response.code})}"
      when 500..599
        raise ApiError, "Server error (#{response.code})}"
      end
    end

    def rate_limit_exceeded?(response)
      return true if response.code.to_i == 429

      return false unless response.code.to_i == 200

      body_content = response.body.to_s
      return false if body_content.length > 1000

      body_content.match?(/rate.?limit|quota.?exceeded/i)
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
      # Log seulement si mode verbose activé
      Logger.debug_if_verbose("Request sent to API", sensitive: true)
      Logger.debug_if_verbose("Response received: #{response.code}", sensitive: false)
    end

    def log_rate_limit_retry(wait_time, attempt)
      message = "Rate limit exceeded, retrying in #{wait_time} seconds (attempt #{attempt + 1})"
      # Log une seule fois par session pour éviter le spam
      Logger.warn_once(message, key: "rate_limit_retry", sensitive: false, ttl: 60)
    end
  end
end

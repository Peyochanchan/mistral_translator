# frozen_string_literal: true

module MistralTranslator
  module ClientHelpers
    # Helper pour la gestion des requêtes HTTP
    module RequestHandler
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
      rescue Net::ReadTimeout, Timeout::Error => e
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
    end

    # Helper pour la gestion des erreurs et retry
    module ErrorHandler
      def make_request_with_retry(prompt, max_tokens, temperature, context, attempt = 0)
        context[:attempt] = attempt
        response = make_request(prompt, max_tokens, temperature)

        # Vérifier les erreurs dans la réponse
        check_response_for_errors(response)

        if rate_limit_exceeded?(response)
          handle_rate_limit(prompt, max_tokens, temperature, context, attempt)
        else
          response
        end
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

      def handle_rate_limit(prompt, max_tokens, temperature, context, attempt)
        unless attempt < @retry_delays.length
          raise RateLimitError, "API rate limit exceeded after #{@retry_delays.length} retries"
        end

        wait_time = @retry_delays[attempt]

        # Trigger callback pour rate limit
        MistralTranslator.configuration.trigger_rate_limit(
          context[:from_locale],
          context[:to_locale],
          wait_time,
          attempt + 1
        )

        log_rate_limit_retry(wait_time, attempt)
        sleep(wait_time)
        make_request_with_retry(prompt, max_tokens, temperature, context, attempt + 1)
      end
    end

    # Helper pour la gestion des batches
    module BatchHandler
      def process_batch_slice(batch)
        results = []
        success_count = 0
        error_count = 0

        batch.each do |request|
          context = {
            from_locale: request[:from],
            to_locale: request[:to],
            attempt: 0
          }

          result = complete(request[:prompt], context: context)
          results << {
            success: true,
            result: result,
            original_request: request
          }
          success_count += 1
        rescue StandardError => e
          results << {
            success: false,
            error: e.message,
            original_request: request
          }
          error_count += 1
        end

        { results: results, success_count: success_count, error_count: error_count }
      end
    end

    # Helper pour le logging
    module LoggingHelper
      def log_request_response(request_body, response)
        # Log seulement si mode verbose activé
        Logger.debug_if_verbose("Request sent to API: #{request_body.to_json}", sensitive: true)
        Logger.debug_if_verbose("Response received: #{response.code}", sensitive: false)
      end

      def log_rate_limit_retry(wait_time, attempt)
        message = "Rate limit exceeded, retrying in #{wait_time} seconds (attempt #{attempt + 1})"
        # Log une seule fois par session pour éviter le spam
        Logger.warn_once(message, key: "rate_limit_retry", sensitive: false, ttl: 60)
      end
    end
  end
end

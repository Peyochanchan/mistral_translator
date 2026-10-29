# frozen_string_literal: true

require "net/http/persistent"

module MistralTranslator
  module ClientHelpers
    # Helper pour la gestion des requêtes HTTP
    module RequestHandler
      def make_request(prompt, max_tokens, temperature, json: false)
        uri = URI("#{@base_uri}/v1/chat/completions")

        request_body = build_request_body(prompt, max_tokens, temperature, json: json)

        request = Net::HTTP::Post.new(uri.path, headers)
        request.body = request_body.to_json

        response = http_pool.request(uri, request)
        log_request_response(request_body, response)

        response
      rescue Net::ReadTimeout, Timeout::Error => e
        raise ApiError, "Request timeout: #{e.message}"
      rescue Net::HTTPError => e
        raise ApiError, "HTTP error: #{e.message}"
      rescue Net::HTTP::Persistent::Error => e
        # Proxy ou API injoignable ; le message d'origine peut citer l'adresse du proxy
        raise ApiError, "Connection failed (#{e.class})", cause: nil
      end

      def http_pool
        @http_pool ||= begin
          pool = Net::HTTP::Persistent.new(name: "mistral_translator")
          pool.read_timeout = MistralTranslator.configuration.read_timeout
          pool.idle_timeout = 30
          pool.open_timeout = MistralTranslator.configuration.open_timeout
          pool.max_requests = 100

          # SSL/TLS configuration
          configure_ssl(pool)
          configure_proxy(pool)

          pool
        end
      end

      def configure_ssl(pool)
        config = MistralTranslator.configuration

        # SSL verify mode
        pool.verify_mode = case config.ssl_verify_mode
                           when :peer then OpenSSL::SSL::VERIFY_PEER
                           when :none then OpenSSL::SSL::VERIFY_NONE
                           else config.ssl_verify_mode
                           end

        # Custom CA certificate file
        pool.ca_file = config.ssl_ca_file if config.ssl_ca_file

        # Custom CA certificates directory
        pool.ca_path = config.ssl_ca_path if config.ssl_ca_path
      end

      def configure_proxy(pool)
        proxy_uri = Proxy.resolve(MistralTranslator.configuration.proxy, host: URI(@base_uri).host)
        pool.proxy = proxy_uri if proxy_uri
      end

      def build_request_body(prompt, max_tokens, temperature, json: false)
        body = {
          model: @model,
          messages: request_messages(prompt)
        }

        body[:max_tokens] = max_tokens if max_tokens
        body[:temperature] = temperature if temperature
        # L'API garantit alors un objet JSON syntaxiquement valide
        body[:response_format] = { type: "json_object" } if json

        body
      end

      # Un Prompt sépare consignes et texte ; une String part en un seul message.
      def request_messages(prompt)
        return prompt.messages if prompt.respond_to?(:messages)

        [{ role: "user", content: prompt }]
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
      # request_options : max_tokens, temperature, json
      def make_request_with_retry(prompt, request_options, context, attempt = 0)
        context[:attempt] = attempt
        response = make_request(prompt, request_options[:max_tokens], request_options[:temperature],
                                json: request_options.fetch(:json, false))

        # Vérifier les erreurs dans la réponse
        check_response_for_errors(response)

        if rate_limit_exceeded?(response)
          handle_rate_limit(prompt, request_options, context, attempt)
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
          raise ApiError, "Client error (#{response.code})"
        when 500..599
          raise ApiError, "Server error (#{response.code})"
        end
      end

      # Seul le statut compte : le corps d'une réponse 200 contient le texte traduit,
      # qui peut très bien parler de « rate limit ».
      def rate_limit_exceeded?(response)
        response.code.to_i == 429
      end

      def handle_rate_limit(prompt, request_options, context, attempt)
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
        make_request_with_retry(prompt, request_options, context, attempt + 1)
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

          result = complete(request[:prompt], context: context, json: true)
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
      # Jamais le contenu des messages : seulement le modèle et les tailles
      def log_request_response(request_body, response)
        sizes = request_body[:messages].map { |message| "#{message[:role]}=#{message[:content].to_s.length}" }
        Logger.debug_if_verbose(
          "Request sent to API: model=#{request_body[:model]} #{sizes.join(" ")}, response #{response.code}",
          sensitive: false
        )
      end

      def log_rate_limit_retry(wait_time, attempt)
        message = "Rate limit exceeded, retrying in #{wait_time} seconds (attempt #{attempt + 1})"
        # Log une seule fois par session pour éviter le spam
        Logger.warn_once(message, key: "rate_limit_retry", sensitive: false, ttl: 60)
      end
    end
  end
end

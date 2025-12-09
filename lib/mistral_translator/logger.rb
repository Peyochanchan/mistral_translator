# frozen_string_literal: true

module MistralTranslator
  module Logger
    class << self
      def info(message, sensitive: false)
        log(:info, message, sensitive)
      end

      def warn(message, sensitive: false)
        log(:warn, message, sensitive)
      end

      def debug(message, sensitive: false)
        log(:debug, message, sensitive)
      end

      # Log seulement si pas déjà loggé récemment (évite la spam)
      def warn_once(message, key: nil, sensitive: false, ttl: 300)
        cache_mutex.synchronize do
          @warn_cache ||= {}
          cache_key = key || message

          return unless should_log_warning?(cache_key, ttl)

          @warn_cache[cache_key] = Time.now
        end

        log(:warn, message, sensitive)
      end

      # Log de debug seulement si vraiment nécessaire
      def debug_if_verbose(message, sensitive: false)
        return unless ENV["MISTRAL_TRANSLATOR_VERBOSE"] == "true"

        log(:debug, message, sensitive)
      end

      private

      def log(level, message, sensitive)
        # Sanitiser le message si sensible
        sanitized_message = sensitive ? sanitize_log_data(message) : message

        # En mode Rails, utiliser le logger Rails
        if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger.public_send(level, "[MistralTranslator] #{sanitized_message}")
        # Sinon, utiliser puts si debug activé (même pour les messages sensibles, ils sont déjà sanitisés)
        elsif ENV["MISTRAL_TRANSLATOR_DEBUG"] == "true"
          puts "[MistralTranslator] #{sanitized_message}"
        end
      end

      def sanitize_log_data(data)
        return data unless data.is_a?(String)

        # Masquer les clés API Bearer
        data = data.gsub(/Bearer\s+[A-Za-z0-9_-]+/, "Bearer [REDACTED]")

        # Masquer les clés API dans les URLs
        data = data.gsub(/[?&]api_key=[A-Za-z0-9_-]+/, "?api_key=[REDACTED]")

        # Masquer les tokens d'authentification
        data = data.gsub(/token=\s*[A-Za-z0-9_-]+/, "token=[REDACTED]")
        data = data.gsub(/token:\s*[A-Za-z0-9_-]+/, "token: [REDACTED]")

        # Masquer les mots de passe
        data = data.gsub(/password=\s*[^\s&]+/, "password=[REDACTED]")
        data = data.gsub(/password:\s*[^\s&]+/, "password: [REDACTED]")

        # Masquer les secrets
        data.gsub(/secret[=:]\s*[A-Za-z0-9_-]+/, "secret=[REDACTED]")
      end

      def should_log_warning?(key, ttl)
        return true unless @warn_cache[key]

        Time.now - @warn_cache[key] > ttl
      end

      def cache_mutex
        @cache_mutex ||= Mutex.new
      end
    end
  end
end

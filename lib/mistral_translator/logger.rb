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
        @warn_cache ||= {}
        cache_key = key || message

        return unless should_log_warning?(cache_key, ttl)

        @warn_cache[cache_key] = Time.now
        log(:warn, message, sensitive)
      end

      # Log de debug seulement si vraiment nécessaire
      def debug_if_verbose(message, sensitive: false)
        return unless ENV["MISTRAL_TRANSLATOR_VERBOSE"] == "true"

        log(:debug, message, sensitive)
      end

      private

      def log(level, message, sensitive)
        # En mode Rails, utiliser le logger Rails
        if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger.public_send(level, "[MistralTranslator] #{message}")
        # Sinon, utiliser puts seulement si pas sensible et debug activé
        elsif !sensitive && ENV["MISTRAL_TRANSLATOR_DEBUG"] == "true"
          puts "[MistralTranslator] #{message}"
        end
      end

      def should_log_warning?(key, ttl)
        return true unless @warn_cache[key]

        Time.now - @warn_cache[key] > ttl
      end
    end
  end
end

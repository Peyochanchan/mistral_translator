# frozen_string_literal: true

require_relative "logger"

module MistralTranslator
  # Relances communes aux traductions et aux résumés.
  # Le client relance déjà les 429 avec backoff : ici, quelques tentatives de plus suffisent.
  module Retries
    RETRY_COUNT = 3
    RETRY_DELAY = 2

    private

    # Exécute le bloc, qui reçoit le numéro de tentative (0 pour la première).
    # Une réponse inexploitable est relancée avec un backoff exponentiel, un quota dépassé
    # après un délai fixe ; au-delà de RETRY_COUNT relances, l'erreur remonte.
    # operation et subject nomment la requête dans les journaux, jamais son contenu.
    def with_retries(operation:, subject:)
      attempt = 0
      begin
        yield attempt
      rescue EmptyTranslationError, InvalidResponseError => e
        raise if attempt >= RETRY_COUNT

        wait_time = RETRY_DELAY * (2**attempt)
        attempt += 1
        log_retry(operation, subject, e, attempt, wait_time)
        sleep(wait_time)
        retry
      rescue RateLimitError
        raise if attempt >= RETRY_COUNT

        attempt += 1
        log_rate_limit_hit(operation, subject)
        sleep(RETRY_DELAY)
        retry
      end
    end

    def log_retry(operation, subject, error, attempt, wait_time)
      message = "#{operation} retry #{attempt}/#{RETRY_COUNT} for #{subject} in #{wait_time}s: #{error.message}"
      Logger.warn_once(message, key: "#{operation}_retry_#{subject}_#{error.class.name}", sensitive: false, ttl: 120)
    end

    def log_rate_limit_hit(operation, subject)
      Logger.warn_once("Rate limit hit for #{operation} #{subject}, retrying",
                       key: "#{operation}_rate_limit_#{subject}", sensitive: false, ttl: 300)
    end
  end
end

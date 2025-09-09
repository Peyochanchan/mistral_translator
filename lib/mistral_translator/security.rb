# frozen_string_literal: true

# Module de sécurité optionnel - chargé seulement si nécessaire
module MistralTranslator
  module Security
    # Validation basique des entrées (version légère)
    module BasicValidator
      MAX_TEXT_LENGTH = 50_000
      MIN_TEXT_LENGTH = 1

      class << self
        def validate_text!(text)
          # Accepter nil et texte vide - ce sont des cas d'usage légitimes
          return "" if text.nil? || text.empty?

          text_str = text.to_s
          return "" if text_str.strip.empty?

          raise ArgumentError, "Text too long (max #{MAX_TEXT_LENGTH} chars)" if text_str.length > MAX_TEXT_LENGTH

          text_str
        end

        def validate_batch!(texts)
          raise ArgumentError, "Batch cannot be nil" if texts.nil?
          raise ArgumentError, "Batch must be an array" unless texts.is_a?(Array)
          raise ArgumentError, "Batch cannot be empty" if texts.empty?
          raise ArgumentError, "Batch too large (max 20 items)" if texts.size > 20

          texts.each { |text| validate_text!(text) }
          texts
        end
      end
    end

    # Rate limiter basique (version légère)
    class BasicRateLimiter
      def initialize(max_requests: 50, window_seconds: 60)
        @max_requests = max_requests
        @window_seconds = window_seconds
        @requests = []
        @mutex = Mutex.new
      end

      def wait_and_record!
        @mutex.synchronize do
          cleanup_old_requests
          if @requests.size >= @max_requests
            wait_time = calculate_wait_time
            sleep(wait_time) if wait_time.positive?
          end
          @requests << Time.now
        end
      end

      private

      def cleanup_old_requests
        cutoff_time = Time.now - @window_seconds
        @requests.reject! { |request_time| request_time < cutoff_time }
      end

      def calculate_wait_time
        return 0 if @requests.empty?

        oldest_request = @requests.min
        time_until_oldest_expires = (oldest_request + @window_seconds) - Time.now
        [time_until_oldest_expires, 0].max
      end
    end
  end
end

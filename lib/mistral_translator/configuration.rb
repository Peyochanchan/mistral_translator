# frozen_string_literal: true

module MistralTranslator
  class Configuration
    attr_accessor :api_key, :api_url, :model, :default_max_tokens, :default_temperature, :retry_delays,
                  :on_translation_start, :on_translation_complete, :on_translation_error, :on_rate_limit, :on_batch_complete, :enable_metrics

    def initialize
      @api_key = nil
      @api_url = "https://api.mistral.ai"
      @model = "mistral-small"
      @default_max_tokens = nil
      @default_temperature = nil
      @retry_delays = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]

      # Callbacks pour le monitoring et la customisation
      @on_translation_start = nil
      @on_translation_complete = nil
      @on_translation_error = nil
      @on_rate_limit = nil
      @on_batch_complete = nil
      @enable_metrics = false

      # Métriques intégrées
      @metrics = {
        total_translations: 0,
        total_characters: 0,
        total_duration: 0.0,
        rate_limits_hit: 0,
        errors_count: 0,
        translations_by_language: Hash.new(0)
      }
    end

    def api_key!
      if @api_key.nil?
        raise ConfigurationError,
              "API key is required. Set it with MistralTranslator.configure { |c| c.api_key = 'your_key' }"
      end

      @api_key
    end

    # Méthodes pour les callbacks
    def trigger_translation_start(from_locale, to_locale, text_length)
      @on_translation_start&.call(from_locale, to_locale, text_length, Time.now)

      return unless @enable_metrics

      @metrics[:total_translations] += 1
      @metrics[:total_characters] += text_length
      @metrics[:translations_by_language]["#{from_locale}->#{to_locale}"] += 1
    end

    def trigger_translation_complete(from_locale, to_locale, original_length, translated_length, duration)
      @on_translation_complete&.call(from_locale, to_locale, original_length, translated_length, duration)

      return unless @enable_metrics

      @metrics[:total_duration] += duration
    end

    def trigger_translation_error(from_locale, to_locale, error, attempt)
      @on_translation_error&.call(from_locale, to_locale, error, attempt, Time.now)

      return unless @enable_metrics

      @metrics[:errors_count] += 1
    end

    def trigger_rate_limit(from_locale, to_locale, wait_time, attempt)
      @on_rate_limit&.call(from_locale, to_locale, wait_time, attempt, Time.now)

      return unless @enable_metrics

      @metrics[:rate_limits_hit] += 1
    end

    def trigger_batch_complete(batch_size, total_duration, success_count, error_count)
      @on_batch_complete&.call(batch_size, total_duration, success_count, error_count)
    end

    # Métriques
    def metrics
      return {} unless @enable_metrics

      @metrics.merge({
                       average_translation_time: if @metrics[:total_translations].positive?
                                                   (@metrics[:total_duration] / @metrics[:total_translations]).round(3)
                                                 else
                                                   0
                                                 end,
                       average_characters_per_translation: if @metrics[:total_translations].positive?
                                                             (@metrics[:total_characters] / @metrics[:total_translations]).round(0)
                                                           else
                                                             0
                                                           end,
                       error_rate: if @metrics[:total_translations].positive?
                                     ((@metrics[:errors_count].to_f / @metrics[:total_translations]) * 100).round(2)
                                   else
                                     0
                                   end
                     })
    end

    def reset_metrics!
      @metrics = {
        total_translations: 0,
        total_characters: 0,
        total_duration: 0.0,
        rate_limits_hit: 0,
        errors_count: 0,
        translations_by_language: Hash.new(0)
      }
    end

    # Configuration helpers pour les callbacks les plus communs
    def setup_rails_logging
      return unless defined?(Rails)

      @on_translation_start = lambda { |from, to, length, _timestamp|
        Rails.logger.info "[MistralTranslator] Starting translation #{from}->#{to} (#{length} chars)"
      }

      @on_translation_complete = lambda { |from, to, _orig_len, _trans_len, duration|
        Rails.logger.info "[MistralTranslator] Completed #{from}->#{to} in #{duration.round(2)}s"
      }

      @on_translation_error = lambda { |from, to, error, attempt, _timestamp|
        Rails.logger.error "[MistralTranslator] Error #{from}->#{to} (attempt #{attempt}): #{error.message}"
      }

      @on_rate_limit = lambda { |from, to, wait_time, attempt, _timestamp|
        Rails.logger.warn "[MistralTranslator] Rate limit #{from}->#{to}, waiting #{wait_time}s (attempt #{attempt})"
      }
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Méthodes utilitaires pour les métriques
    def metrics
      configuration.metrics
    end

    def reset_metrics!
      configuration.reset_metrics!
    end
  end
end

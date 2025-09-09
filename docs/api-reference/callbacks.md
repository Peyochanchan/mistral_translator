> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Référence des Callbacks API

## Callbacks Disponibles

### `on_translation_start`

**Déclenchement:** Avant chaque traduction

**Paramètres:** `from_locale, to_locale, text_length, timestamp`

```ruby
MistralTranslator.configure do |config|
  config.on_translation_start = ->(from, to, length, timestamp) {
    Rails.logger.info "🚀 #{from}→#{to} (#{length} chars)"
  }
end
```

### `on_translation_complete`

**Déclenchement:** Après chaque traduction réussie

**Paramètres:** `from_locale, to_locale, original_length, translated_length, duration`

```ruby
config.on_translation_complete = ->(from, to, orig_len, trans_len, duration) {
  Rails.logger.info "✅ #{from}→#{to} in #{duration.round(2)}s"

  # Métriques custom
  StatsTracker.record(:translation, {
    languages: "#{from}_to_#{to}",
    duration: duration,
    efficiency: trans_len.to_f / orig_len
  })
}
```

### `on_translation_error`

**Déclenchement:** Lors d'erreurs de traduction

**Paramètres:** `from_locale, to_locale, error, attempt, timestamp`

```ruby
config.on_translation_error = ->(from, to, error, attempt, timestamp) {
  Rails.logger.error "❌ #{from}→#{to} attempt #{attempt}: #{error.message}"

  # Notification externe
  Sentry.capture_exception(error, extra: { from: from, to: to, attempt: attempt })
}
```

### `on_rate_limit`

**Déclenchement:** Lors de rate limiting

**Paramètres:** `from_locale, to_locale, wait_time, attempt, timestamp`

```ruby
config.on_rate_limit = ->(from, to, wait_time, attempt, timestamp) {
  Rails.logger.warn "⏳ Rate limit #{from}→#{to}, waiting #{wait_time}s (attempt #{attempt})"

  # Slack notification pour rate limits fréquents
  SlackNotifier.warn("Translation rate limit hit") if attempt > 3
}
```

### `on_batch_complete`

**Déclenchement:** Après completion d'un batch

**Paramètres:** `batch_size, total_duration, success_count, error_count`

```ruby
config.on_batch_complete = ->(size, duration, success, errors) {
  Rails.logger.info "📦 Batch: #{success}/#{size} success in #{duration.round(2)}s"

  # Alertes si trop d'erreurs
  if errors > size * 0.1  # Plus de 10% d'erreurs
    AlertService.notify("High batch error rate: #{errors}/#{size}")
  end
}
```

## Configuration Rapide

### Setup Rails Automatique

```ruby
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
  config.enable_metrics = true
  config.setup_rails_logging  # Configure tous les callbacks Rails
end
```

### Setup Custom Complet

```ruby
MistralTranslator.configure do |config|
  # Métriques
  config.enable_metrics = true

  # Callbacks essentiels
  config.on_translation_start = ->(from, to, length, ts) {
    Rails.cache.increment("translations_started")
  }

  config.on_translation_complete = ->(from, to, orig, trans, dur) {
    # Cache performance data
    Rails.cache.write("last_translation_time", dur)
    Rails.cache.increment("translations_completed")
  }

  config.on_translation_error = ->(from, to, error, attempt, ts) {
    # Structured logging
    Rails.logger.error({
      event: "translation_error",
      from: from, to: to,
      error: error.class.name,
      attempt: attempt,
      timestamp: ts
    }.to_json)
  }
end
```

## Patterns Utiles

### Circuit Breaker avec Callbacks

```ruby
class TranslationCircuitBreaker
  def self.setup!
    @failure_count = 0
    @last_reset = Time.now

    MistralTranslator.configure do |config|
      config.on_translation_error = method(:on_error)
      config.on_translation_complete = method(:on_success)
    end
  end

  def self.on_error(from, to, error, attempt, timestamp)
    @failure_count += 1
    if @failure_count > 5 && Time.now - @last_reset < 300 # 5 min
      Rails.cache.write("translation_circuit_open", true, expires_in: 10.minutes)
    end
  end

  def self.on_success(from, to, orig, trans, duration)
    @failure_count = 0 if @failure_count > 0
  end
end
```

### Adaptive Rate Limiting

```ruby
class AdaptiveRateManager
  def self.setup!
    @success_rate = 1.0

    MistralTranslator.configure do |config|
      config.on_rate_limit = method(:on_rate_limit)
      config.on_translation_complete = method(:on_success)
    end
  end

  def self.on_rate_limit(from, to, wait_time, attempt, timestamp)
    # Réduire la fréquence des futures requêtes
    @success_rate *= 0.8
    Rails.cache.write("translation_delay", 2.0 / @success_rate)
  end

  def self.on_success(from, to, orig, trans, duration)
    # Gradually increase rate
    @success_rate = [@success_rate * 1.1, 1.0].min
  end
end
```

### Monitoring Dashboard Data

```ruby
class TranslationMetrics
  def self.setup_callbacks!
    MistralTranslator.configure do |config|
      config.on_translation_complete = method(:track_success)
      config.on_translation_error = method(:track_error)
      config.on_batch_complete = method(:track_batch)
    end
  end

  def self.track_success(from, to, orig_len, trans_len, duration)
    Redis.current.multi do |r|
      r.incr("translations:#{Date.current}:success")
      r.incr("translations:#{from}_to_#{to}:count")
      r.lpush("translations:durations", duration)
      r.ltrim("translations:durations", 0, 999)  # Keep last 1000
    end
  end

  def self.track_error(from, to, error, attempt, timestamp)
    Redis.current.multi do |r|
      r.incr("translations:#{Date.current}:errors")
      r.incr("translations:#{error.class.name}:count")
    end
  end

  def self.get_dashboard_data
    {
      today_success: Redis.current.get("translations:#{Date.current}:success").to_i,
      today_errors: Redis.current.get("translations:#{Date.current}:errors").to_i,
      avg_duration: Redis.current.lrange("translations:durations", 0, -1)
                          .map(&:to_f).sum / 1000.0,
      language_pairs: Redis.current.keys("translations:*_to_*:count")
                           .map { |k| [k.split(':')[1], Redis.current.get(k).to_i] }
    }
  end
end
```

---

[← Methods](api-reference/methods.md) | [Errors](api-reference/errors.md) | [Callbacks](api-reference/callbacks.md) | [Configuration](api-reference/configuration.md) →

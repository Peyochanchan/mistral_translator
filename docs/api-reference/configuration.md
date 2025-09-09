> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Configuration API

Référence complète des options de configuration.

## Options Principales

```ruby
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']        # Obligatoire
  config.model = "mistral-small"                 # Défaut
  config.api_url = "https://api.mistral.ai"      # URL API
  config.default_max_tokens = 4000               # Limite tokens
  config.default_temperature = 0.3               # Créativité (0-1)
  config.retry_delays = [2, 4, 8, 16, 32]       # Délais retry (secondes)
  config.enable_metrics = false                  # Suivi des stats
end
```

## Callbacks

```ruby
config.on_translation_start = ->(from, to, length, timestamp) { }
config.on_translation_complete = ->(from, to, orig_len, trans_len, duration) { }
config.on_translation_error = ->(from, to, error, attempt, timestamp) { }
config.on_rate_limit = ->(from, to, wait_time, attempt, timestamp) { }
config.on_batch_complete = ->(batch_size, duration, success, errors) { }
```

## Métriques

```ruby
# Activer
config.enable_metrics = true

# Consulter
MistralTranslator.metrics
# => {
#   total_translations: 42,
#   average_translation_time: 1.2,
#   error_rate: 2.1,
#   translations_by_language: {...}
# }

# Réinitialiser
MistralTranslator.reset_metrics!
```

## Helper Rails

```ruby
# Configuration Rails automatique
config.setup_rails_logging  # Active les logs Rails standard
```

## Validation

```ruby
# Test de configuration
MistralTranslator.health_check
# => { status: :ok, message: "API connection successful" }

# Langues supportées
MistralTranslator.supported_locales
# => ["fr", "en", "es", "pt", "de", "it", "nl", "ru", "mg", "ja", "ko", "zh", "ar"]
```

---

**API-Reference Navigation:**
[← Methods](api-reference/methods.md) | [Errors](api-reference/errors.md) | [Callbacks](api-reference/callbacks.md) | [Configuration](api-reference/configuration.md) →

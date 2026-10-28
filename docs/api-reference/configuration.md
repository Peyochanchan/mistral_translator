> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Configuration API

Référence complète des options de configuration.

## Options Principales

```ruby
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']        # Obligatoire
  config.model = "mistral-small-latest"                 # Défaut
  config.api_url = "https://api.mistral.ai"      # URL API
  config.default_max_tokens = 4000               # Limite tokens
  config.default_temperature = 0.3               # Créativité (0-1)
  config.retry_delays = [2, 4, 8, 16, 32]       # Délais retry (secondes)
  config.enable_metrics = false                  # Suivi des stats
  config.proxy = nil                             # Proxy HTTP (désactivé par défaut)
end
```

## Proxy

Désactivé par défaut. Trois valeurs possibles :

```ruby
config.proxy = nil                                  # Aucun proxy (défaut)
config.proxy = "http://user:password@proxy:3128"    # Ce proxy (String ou URI)
config.proxy = :env                                 # HTTPS_PROXY, puis HTTP_PROXY ; NO_PROXY respecté
```

- Seuls les proxys `http://` sont acceptés. La bibliothèque HTTP utilisée parle toujours en clair au proxy : avec `https://`, les identifiants du proxy circuleraient sans chiffrement. Le flux vers l'API Mistral reste chiffré de bout en bout (tunnel `CONNECT` puis TLS).
- Avec `:env`, `NO_PROXY` suit les règles de curl : `*`, un domaine et ses sous-domaines (`mistral.ai`, `.mistral.ai`, `*.mistral.ai`), éventuellement avec le port 443.
- Une valeur invalide lève `ConfigurationError` dès l'affectation ; le message ne reprend jamais l'URL, pour ne pas exposer les identifiants.
- `api_url` reste verrouillée sur `https://api.mistral.ai`.
- Définissez le proxy avant la première traduction : le client et sa connexion sont créés une fois puis réutilisés.

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

# Langues supportées : les 182 codes ISO 639-1
MistralTranslator.supported_locales
# => ["aa", "ab", "ae", "af", ..., "zh", "zu"]
```

---

**API-Reference Navigation:**
[← Methods](api-reference/methods.md) | [Errors](api-reference/errors.md) | [Callbacks](api-reference/callbacks.md) | [Configuration](api-reference/configuration.md) →

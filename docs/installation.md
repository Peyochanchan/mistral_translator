> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Installation et Configuration

Installation et configuration de base de MistralTranslator.

## 📦 Installation

```ruby
# Gemfile
gem 'mistral_translator'
```

```bash
bundle install
```

## 🔑 Configuration de Base

### 1. Clé API Mistral

1. Créez un compte sur [console.mistral.ai](https://console.mistral.ai)
2. Générez une clé API
3. Stockez-la en variable d'environnement :

```bash
# .env
MISTRAL_API_KEY=your_api_key_here
```

### 2. Configuration Minimale

```ruby
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
end
```

### 3. Test

```ruby
# Test rapide
result = MistralTranslator.translate("Hello", from: "en", to: "fr")
puts result
# => "Bonjour"
```

## ⚙️ Configuration Rails

```ruby
# config/initializers/mistral_translator.rb
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
  config.enable_metrics = Rails.env.production?

  case Rails.env
  when 'development'
    config.setup_rails_logging
    config.retry_delays = [1, 2, 4]

  when 'production'
    config.retry_delays = [2, 4, 8, 16, 32]

    # Intégration Sentry (optionnel)
    config.on_translation_error = ->(from, to, error, attempt, timestamp) {
      Sentry.capture_exception(error) if defined?(Sentry) && attempt > 2
    }
  end
end
```

## 🔧 Options Principales

```ruby
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
  config.model = "mistral-small"                # Modèle par défaut
  config.retry_delays = [2, 4, 8, 16]          # Délais retry
  config.enable_metrics = true                  # Suivi des stats
  config.default_max_tokens = 4000              # Limite tokens
  config.default_temperature = 0.3              # Créativité
end
```

## 🧪 Script de Validation

```ruby
# test_installation.rb
require 'mistral_translator'

MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
end

tests = [
  -> { MistralTranslator.translate("Hello", from: "en", to: "fr") },
  -> { MistralTranslator::LocaleHelper.locale_supported?("fr") },
  -> { MistralTranslator.metrics.is_a?(Hash) }
]

tests.each_with_index do |test, i|
  begin
    test.call
    puts "✅ Test #{i + 1}: PASS"
  rescue => e
    puts "❌ Test #{i + 1}: #{e.message}"
  end
end
```

## 🚨 Problèmes Courants

**Clé API manquante :**

```ruby
# Vérifiez
puts ENV['MISTRAL_API_KEY']  # Ne doit pas être nil
```

**Authentification échouée :**

- Vérifiez la clé sur console.mistral.ai
- Régénérez si nécessaire

**Timeout réseau :**

```ruby
config.retry_delays = [3, 6, 12, 24]  # Délais plus longs
```

## 📚 Prochaines Étapes

- **Débutant ?** → [Guide de Démarrage](getting-started.md)
- **Rails ?** → [Rails Integration](rails-integration/setup.md)
- **Avancé ?** → [Traductions Avancées](advanced-usage/translations.md)

---

**Documentation Navigation:**
[← Installation](installation.md) | [Getting Started](getting-started.md) | [Migration Guide](migration-0.1.0-to-0.2.0.md) →

**Sections:** [API Reference](api-reference/) | [Advanced Usage](advanced-usage/) | [Rails Integration](rails-integration/)

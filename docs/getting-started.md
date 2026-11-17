> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Guide de Démarrage

Premiers pas avec MistralTranslator : exemples concrets pour débuter rapidement.

## 🚀 Première Traduction

```ruby
require 'mistral_translator'

MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
end

result = MistralTranslator.translate("Bonjour le monde", from: "fr", to: "en")
puts result
# => "Hello world"
```

## 📝 Traductions de Base

```ruby
# Français → Anglais
MistralTranslator.translate("Comment ça va ?", from: "fr", to: "en")
# => "How are you?"

# Anglais → Espagnol
MistralTranslator.translate("Good morning", from: "en", to: "es")
# => "Buenos días"

# Auto-détection de langue
MistralTranslator.translate_auto("Guten Tag", to: "fr")
# => "Bonjour"
```

## 🌍 Langues Supportées

```ruby
# 619 langues : codes ISO 639-1 (deux lettres) et ISO 639-3 (trois lettres)
MistralTranslator::LocaleHelper.supported_locales
# => ["aa", "ab", "ace", "acf", ..., "zun", "zza"]

# Une écriture et une région précisent la variante
MistralTranslator.translate("Bonjour", from: "fr", to: "pt-BR")
MistralTranslator.translate("Bonjour", from: "fr", to: "zh-Hant-TW")

# Les noms de langue et les codes ISO 639-3 sont acceptés à la place du code
MistralTranslator::Locale.parse("allemand").to_s # => "de"
MistralTranslator::Locale.parse("hat").to_s      # => "ht"

# Vérifier une langue spécifique
MistralTranslator::LocaleHelper.locale_supported?("ja")
# => true
```

Les langues, écritures et régions viennent des données CLDR de macOS 27.2, via `bin/generate_languages` (2026-11-17). Les variantes et extensions BCP 47 (`ca-ES-valencia`, `en-US-u-ca-gregory`) ne sont pas acceptées.

La qualité de traduction dépend du modèle Mistral : excellente pour les langues les plus parlées, plus faible pour les langues rares. Vérifiez le résultat avant de vous appuyer sur une langue rare.

## 🚨 Gestion d'Erreurs Simple

```ruby
def safe_translate(text, from:, to:)
  return "" if text.blank?
  return text if from == to

  MistralTranslator.translate(text, from: from, to: to)
rescue MistralTranslator::RateLimitError
  "Limite API atteinte, réessayez plus tard"
rescue MistralTranslator::Error => e
  Rails.logger.error "Translation error: #{e.message}"
  text  # Fallback vers original
end
```

## ⚡ Traduction Multiple

```ruby
# Vers plusieurs langues
translator = MistralTranslator::Translator.new
results = translator.translate_to_multiple(
  "Bienvenue",
  from: "fr",
  to: ["en", "es", "de"]
)
# => { "en" => "Welcome", "es" => "Bienvenido", "de" => "Willkommen" }
```

## 🎨 Contexte et Glossaire

_Compatibilité:_ v0.1.0 ne supporte pas `context`/`glossary` via l'API publique. Utilisez une instance `MistralTranslator::Translator`. En v0.2.0, ces options sont supportées par `translator.translate`.

```ruby
translator = MistralTranslator::Translator.new

# Avec contexte
translator.translate(
  "Batterie faible",
  from: "fr", to: "en",
  context: "Smartphone notification"
)
# => "Battery low"

# Avec glossaire
tech_glossary = { "IA" => "AI", "données" => "data" }
translator.translate(
  "L'IA analyse les données",
  from: "fr", to: "en",
  glossary: tech_glossary
)
# => "AI analyzes data"
```

## 📊 Résumés

```ruby
summarizer = MistralTranslator::Summarizer.new

# Résumé simple
summary = summarizer.summarize(long_text, language: "fr", max_words: 100)

# Résumé + traduction
english_summary = summarizer.summarize_and_translate(
  french_text, from: "fr", to: "en", max_words: 150
)
```

## 🛤️ Rails Integration

```ruby
# Dans un modèle
class Article < ApplicationRecord
  def translate_to(language)
    translator = MistralTranslator::Translator.new
    translator.translate(
      title,
      from: I18n.locale.to_s,
      to: language.to_s,
      context: "Blog article title"
    )
  rescue MistralTranslator::Error
    title
  end
end

# Dans un helper
module ApplicationHelper
  def safe_translate(text, to:, context: nil)
    translator = MistralTranslator::Translator.new
    translator.translate(text, from: I18n.locale, to: to, context: context)
  rescue MistralTranslator::Error
    text
  end
end
```

## 📈 Métriques

```ruby
# Activer le suivi
MistralTranslator.configure do |config|
  config.enable_metrics = true
end

# Consulter les stats
metrics = MistralTranslator.metrics
puts "Traductions: #{metrics[:total_translations]}"
puts "Temps moyen: #{metrics[:average_translation_time]}s"
```

## 💾 Cache Recommandé

```ruby
def cached_translate(text, from:, to:)
  cache_key = "translation:#{Digest::MD5.hexdigest(text)}:#{from}:#{to}"

  Rails.cache.fetch(cache_key, expires_in: 24.hours) do
    MistralTranslator.translate(text, from: from, to: to)
  end
rescue MistralTranslator::Error
  text
end
```

---

**Documentation Navigation:**
[← Installation](installation.md) | [Getting Started](getting-started.md) | [Migration Guide](migration-0.1.0-to-0.2.0.md) →

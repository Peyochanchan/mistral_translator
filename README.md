# MistralTranslator - Documentation Usage Avancé

## Table des Matières

- [Installation et Configuration](#installation-et-configuration)
- [Configuration Avancée](#configuration-avancée)
- [Traductions de Base](#traductions-de-base)
- [Adaptateurs pour Rails](#adaptateurs-pour-rails)
- [Traductions en Lot (Batch)](#traductions-en-lot-batch)
- [Résumés Intelligents](#résumés-intelligents)
- [Gestion des Erreurs et Retry](#gestion-des-erreurs-et-retry)
- [Monitoring et Métriques](#monitoring-et-métriques)
- [Intégration Rails Avancée](#intégration-rails-avancée)
- [Sécurité et Rate Limiting](#sécurité-et-rate-limiting)
- [Helpers et Extensions](#helpers-et-extensions)

---

## Installation et Configuration

### Installation de base

```ruby
# Gemfile
gem 'mistral_translator'

# Configuration minimale
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
end
```

### Configuration complète

```ruby
# config/initializers/mistral_translator.rb
MistralTranslator.configure do |config|
  # Configuration API
  config.api_key = ENV['MISTRAL_API_KEY']
  config.model = "mistral-small"
  config.api_url = "https://api.mistral.ai"

  # Configuration retry et timeouts
  config.retry_delays = [2, 4, 8, 16, 32]
  config.default_max_tokens = 4000
  config.default_temperature = 0.7

  # Activation des métriques
  config.enable_metrics = true

  # Configuration du logging Rails
  config.setup_rails_logging if Rails.env.development?
end
```

---

## Configuration Avancée

### Callbacks personnalisés

```ruby
MistralTranslator.configure do |config|
  # Callback au début de traduction
  config.on_translation_start = ->(from, to, text_length, timestamp) {
    Rails.logger.info "🚀 Translation #{from}→#{to} starting (#{text_length} chars)"
    # Notification Slack, métriques custom, etc.
  }

  # Callback de fin de traduction
  config.on_translation_complete = ->(from, to, orig_len, trans_len, duration) {
    Rails.logger.info "✅ Translation #{from}→#{to} completed in #{duration.round(2)}s"

    # Enregistrer en base les stats
    TranslationStat.create!(
      source_language: from,
      target_language: to,
      original_length: orig_len,
      translated_length: trans_len,
      duration: duration
    )
  }

  # Callback d'erreur
  config.on_translation_error = ->(from, to, error, attempt, timestamp) {
    Rails.logger.error "❌ Translation error #{from}→#{to}: #{error.message}"

    # Notification d'erreur critique
    if error.is_a?(MistralTranslator::RateLimitError)
      SlackNotifier.ping("Rate limit atteint sur Mistral API")
    end
  }

  # Callback de rate limit
  config.on_rate_limit = ->(from, to, wait_time, attempt, timestamp) {
    Rails.logger.warn "⏳ Rate limit #{from}→#{to}, wait #{wait_time}s (attempt #{attempt})"
  }

  # Callback de fin de batch
  config.on_batch_complete = ->(batch_size, duration, success_count, error_count) {
    Rails.logger.info "📊 Batch completed: #{success_count}/#{batch_size} success in #{duration.round(2)}s"
  }
end
```

### Configuration par environnement

```ruby
# config/initializers/mistral_translator.rb
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']

  case Rails.env
  when 'development'
    config.enable_metrics = true
    config.setup_rails_logging
    config.retry_delays = [1, 2, 4] # Retry plus rapides en dev

  when 'test'
    # Configuration pour les tests
    config.api_key = 'test-key'
    config.enable_metrics = false

  when 'production'
    config.enable_metrics = true
    config.retry_delays = [2, 4, 8, 16, 32, 64]

    # Logging production optimisé
    config.on_translation_error = ->(from, to, error, attempt, timestamp) {
      Sentry.capture_exception(error, extra: {
        translation: { from: from, to: to, attempt: attempt }
      })
    }
  end
end
```

---

## Traductions de Base

### Traduction simple

```ruby
# Traduction de base
result = MistralTranslator.translate(
  "Bonjour le monde",
  from: "fr",
  to: "en"
)
# => "Hello world"

# Avec contexte et glossaire
result = MistralTranslator.translate(
  "Le produit est disponible en stock",
  from: "fr",
  to: "en",
  context: "E-commerce website, product page",
  glossary: { "produit" => "item", "stock" => "inventory" }
)
# => "The item is available in inventory"
```

### Traduction avec préservation HTML

```ruby
html_content = "<h1>Titre Principal</h1><p>Contenu du paragraphe avec <strong>texte important</strong></p>"

result = MistralTranslator.translate(
  html_content,
  from: "fr",
  to: "en",
  preserve_html: true
)
# => "<h1>Main Title</h1><p>Paragraph content with <strong>important text</strong></p>"
```

### Auto-détection de langue

```ruby
# La gem détecte automatiquement la langue source
result = MistralTranslator.translate_auto(
  "Ceci est un texte en français",
  to: "en",
  context: "Technical documentation"
)
# => "This is a text in French"
```

### Traduction avec score de confiance

```ruby
result = MistralTranslator.translate_with_confidence(
  "Le chat mange la souris",
  from: "fr",
  to: "en"
)

puts result[:translation]   # => "The cat eats the mouse"
puts result[:confidence]    # => 0.85
puts result[:metadata]      # => { source_locale: "fr", target_locale: "en", ... }
```

---

## Adaptateurs pour Rails

MistralTranslator s'intègre parfaitement avec les gems de traduction Rails populaires.

### Avec Mobility

```ruby
# Modèle avec Mobility
class Article < ApplicationRecord
  extend Mobility
  translates :title, :content, backend: :key_value
end

# Traduction automatique de tous les champs
article = Article.create!(title: "Mon super article", content: "Contenu détaillé...")

# Méthode simple
success = MistralTranslator::RecordTranslation.translate_mobility_record(
  article,
  [:title, :content],
  source_locale: :fr
)

# Méthode avec adaptateur personnalisé
adapter = MistralTranslator::Adapters::MobilityAdapter.new(article)
service = MistralTranslator::Adapters::RecordTranslationService.new(
  article,
  [:title, :content],
  adapter: adapter,
  source_locale: :fr
)

if service.translate_to_all_locales
  puts "Article traduit avec succès dans toutes les langues !"

  # Vérifier les traductions
  I18n.available_locales.each do |locale|
    puts "#{locale}: #{article.title(locale: locale)}"
  end
end
```

### Avec Globalize

```ruby
# Modèle avec Globalize
class Product < ApplicationRecord
  translates :name, :description, fallbacks_for_empty_translations: true
end

# Traduction avec Globalize
product = Product.create!(name: "Smartphone Premium", description: "Le meilleur téléphone...")

success = MistralTranslator::RecordTranslation.translate_globalize_record(
  product,
  [:name, :description],
  source_locale: :fr
)

if success
  # Accès aux traductions
  I18n.with_locale(:en) do
    puts product.name        # => "Premium Smartphone"
    puts product.description # => "The best phone..."
  end
end
```

### Avec attributs I18n personnalisés

```ruby
# Modèle avec suffixes de langue
class Page < ApplicationRecord
  # title_fr, title_en, content_fr, content_en, etc.
end

# Traduction automatique
page = Page.create!(
  title_fr: "À propos de nous",
  content_fr: "Notre entreprise..."
)

success = MistralTranslator::RecordTranslation.translate_record(
  page,
  [:title, :content],
  source_locale: :fr
)

puts page.title_en  # => "About Us"
puts page.content_en # => "Our company..."
```

### Adaptateur personnalisé

```ruby
# Pour des méthodes custom de traduction
class CustomTranslatableModel < ApplicationRecord
  def get_translation(field, locale)
    translations[locale.to_s]&.[](field.to_s)
  end

  def set_translation(field, locale, value)
    self.translations ||= {}
    self.translations[locale.to_s] ||= {}
    self.translations[locale.to_s][field.to_s] = value
  end

  def available_locales
    [:fr, :en, :es, :de]
  end
end

# Utilisation avec adaptateur custom
model = CustomTranslatableModel.new
success = MistralTranslator::RecordTranslation.translate_custom_record(
  model,
  [:title, :description],
  get_method: :get_translation,
  set_method: :set_translation,
  locales_method: :available_locales,
  source_locale: :fr
)
```

# Modèle Rails avec résumés automatiques

class Article < ApplicationRecord
after_save :generate_summaries, if: :saved_change_to_content?

private

def generate_summaries
return unless content.present?

    summarizer = MistralTranslator::Summarizer.new

    # Génération de résumés multi-niveaux
    summaries = summarizer.summarize_tiered(
      content,
      language: I18n.locale,
      short: 50,
      medium: 150,
      long: 300
    )

    update_columns(
      short_summary: summaries[:short],
      medium_summary: summaries[:medium],
      long_summary: summaries[:long],
      summaries_generated_at: Time.current
    )

    # Job asynchrone pour traductions
    TranslateSummariesJob.perform_later(id) if I18n.available_locales.size > 1

rescue MistralTranslator::Error => e
Rails.logger.error "Erreur génération résumé pour Article #{id}: #{e.message}"
end
end

# Job pour traduction des résumés

class TranslateSummariesJob < ApplicationJob
def perform(article_id)
article = Article.find(article_id)
summarizer = MistralTranslator::Summarizer.new

    target_locales = I18n.available_locales - [I18n.locale]

    target_locales.each do |locale|
      next if article.send("short_summary_#{locale}").present?

      summaries = summarizer.summarize_to_multiple(
        article.content,
        languages: [locale],
        max_words: 150
      )

      article.update_column("medium_summary_#{locale}", summaries[locale.to_s])

      # Rate limiting entre les traductions
      sleep(2)
    end

end
end

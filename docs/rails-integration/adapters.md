> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md) • [💻 Examples](../examples/) • [📊 GitHub](https://github.com/peyochanchan/mistral_translator)

---

# Adaptateurs Rails

Intégration automatique avec les gems d'i18n Rails.

## Mobility

```ruby
class Article < ApplicationRecord
  extend Mobility
  translates :title, :content
end

# Traduction automatique
MistralTranslator::RecordTranslation.translate_mobility_record(
  article, [:title, :content], source_locale: :fr
)
```

## Globalize

```ruby
class Product < ApplicationRecord
  translates :name, :description
end

# Traduction automatique
MistralTranslator::RecordTranslation.translate_globalize_record(
  product, [:name, :description], source_locale: :fr
)
```

## Attributs I18n (title_fr, title_en...)

```ruby
# Colonnes: title_fr, title_en, content_fr, content_en
MistralTranslator::RecordTranslation.translate_record(
  page, [:title, :content], source_locale: :fr
)
```

## Adaptateur Personnalisé

```ruby
class CustomModel < ApplicationRecord
  def get_translation(field, locale)
    translations[locale.to_s]&.[](field.to_s)
  end

  def set_translation(field, locale, value)
    # Votre logique de stockage
  end
end

# Usage
MistralTranslator::RecordTranslation.translate_custom_record(
  model, [:title],
  get_method: :get_translation,
  set_method: :set_translation
)
```

## Détection Automatique

```ruby
# Détecte automatiquement Mobility, Globalize ou I18n
adapter = MistralTranslator::Adapters::AdapterFactory.build_for(record)
service = MistralTranslator::Adapters::RecordTranslationService.new(
  record, [:title, :content], adapter: adapter
)
service.translate_to_all_locales
```

## ActionText Support

ActionText est automatiquement détecté et le HTML est préservé lors de la traduction.

---

**Prochaines étapes :** [Jobs Asynchrones](jobs.md) | [Controllers](controllers.md)

> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Jobs Asynchrones

Traitement des traductions en arrière-plan avec ActiveJob/Sidekiq.

## Job de Base

```ruby
class TranslateRecordJob < ApplicationJob
  def perform(model_class, record_id, fields, source_locale = nil)
    record = model_class.constantize.find(record_id)
    MistralTranslator::RecordTranslation.translate_record(
      record, fields, source_locale: source_locale
    )
  end
end

# Usage
TranslateRecordJob.perform_later("Article", article.id, [:title, :content])
```

## Job avec Retry

```ruby
class TranslateRecordJob < ApplicationJob
  queue_as :translations
  retry_on MistralTranslator::RateLimitError, wait: 30.seconds, attempts: 5
  discard_on MistralTranslator::AuthenticationError

  def perform(model_class, record_id, fields, source_locale = nil)
    # Logique de traduction
  end
end
```

## Déclenchement Automatique

```ruby
# Dans vos modèles
class Article < ApplicationRecord
  after_save :schedule_translation, if: :should_translate?

  private

  def schedule_translation
    TranslateRecordJob.perform_later(
      self.class.name, id, translatable_fields
    )
  end

  def should_translate?
    saved_changes.keys.any? { |field| field.end_with?("_#{I18n.locale}") }
  end
end
```

## Job par Batch

```ruby
class BatchTranslateJob < ApplicationJob
  def perform(records_data)
    records_data.each do |data|
      model = data[:model].constantize.find(data[:id])
      # Traduction avec délai anti-rate limit
      sleep(2)
    end
  end
end
```

## Patterns Recommandés

**Déclenchement :**

- `after_save` callbacks pour traduction automatique
- Jobs programmés pour traduction différée
- Webhooks pour traduction sur événements

**Files :**

- Queue dédiée `translations`
- Priorité basse pour éviter de bloquer l'app
- Retry intelligent selon le type d'erreur

**Optimisations :**

- Batch des traductions par langue cible
- Cache des traductions fréquentes
- Rate limiting avec `sleep()` entre requêtes

---

**Rails Integration Navigation:**
[← Setup](setup.md) | [Adapters](adapters.md) | [Jobs](jobs.md) | [Controllers](controllers.md) →

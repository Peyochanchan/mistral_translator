> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Traitement par Lot (Batch)

Optimisez vos traductions avec le traitement par lot et les traductions multiples.

## 📦 Batch Basique

```ruby
texts = ["Bonjour", "Comment ça va ?", "Au revoir"]

translator = MistralTranslator::Translator.new
results = translator.translate_batch(texts, from: "fr", to: "en")

results.each { |index, translation| puts "#{index}: #{translation}" }
# => 0: Hello
# => 1: How are you?
# => 2: Goodbye
```

## 🌍 Multi-langues

```ruby
# Vers plusieurs langues simultanément
results = translator.translate_to_multiple(
  "Bienvenue",
  from: "fr",
  to: ["en", "es", "de", "it"],
  use_batch: true  # Optimisation
)
# => {"en" => "Welcome", "es" => "Bienvenido", ...}
```

## ⚡ Avec Gestion d'Erreurs

```ruby
# Fallback automatique en cas d'échec
results = MistralTranslator::Helpers.translate_batch_with_fallback(
  texts,
  from: "fr",
  to: "en",
  fallback_strategy: :individual  # Retry individuellement
)

results.each do |index, result|
  if result.is_a?(Hash) && result[:error]
    puts "❌ Erreur #{index}: #{result[:error]}"
  else
    puts "✅ #{index}: #{result}"
  end
end
```

## 📊 Avec Progression

```ruby
# Pour gros volumes
MistralTranslator::Helpers.translate_with_progress(
  large_texts.each_with_index.to_h,
  from: "fr",
  to: "en"
) do |current, total, key, result|
  progress = (current.to_f / total * 100).round(1)
  puts "📈 [#{progress}%] #{key}"
end
```

## 🚦 Rate Limiting

```ruby
# Délai intelligent entre batches
def process_large_batch(texts, batch_size: 10)
  texts.each_slice(batch_size).with_index do |batch, i|
    results = translator.translate_batch(batch, from: "fr", to: "en")

    # Pause entre batches (sauf le dernier)
    sleep(2) unless i == (texts.size / batch_size.to_f).ceil - 1
  end
end
```

## 💾 Avec Cache

```ruby
def cached_batch_translate(texts, from:, to:)
  results = []
  to_translate = []

  # Vérifier le cache
  texts.each_with_index do |text, index|
    cache_key = "translation:#{Digest::MD5.hexdigest(text)}:#{from}:#{to}"
    cached = Rails.cache.read(cache_key)

    if cached
      results[index] = cached
    else
      to_translate << { text: text, index: index, cache_key: cache_key }
    end
  end

  # Traduire seulement ce qui n'est pas en cache
  unless to_translate.empty?
    fresh_results = translator.translate_batch(
      to_translate.map { |item| item[:text] },
      from: from, to: to
    )

    # Sauver en cache
    fresh_results.each do |batch_index, translation|
      original_index = to_translate[batch_index][:index]
      cache_key = to_translate[batch_index][:cache_key]

      Rails.cache.write(cache_key, translation, expires_in: 24.hours)
      results[original_index] = translation
    end
  end

  results
end
```

## 📈 Configuration Batch

```ruby
MistralTranslator.configure do |config|
  config.retry_delays = [1, 3, 6]  # Plus rapide pour batch

  config.on_batch_complete = ->(size, duration, success, errors) {
    rate = (success.to_f / size * 100).round(1)
    puts "📊 Batch: #{success}/#{size} (#{rate}%) en #{duration.round(2)}s"
  }
end
```

## 🎯 Patterns Recommandés

**Petits volumes (< 50 textes) :**

- Batch simple sans optimisation

**Moyens volumes (50-500 textes) :**

- Batch avec cache + rate limiting

**Gros volumes (> 500 textes) :**

- Jobs asynchrones + progression + cache

**Multi-langues :**

- `use_batch: true` pour optimisation API

---

**Advanced Usage Navigation:**
[← Translations](translations.md) | [Batch Processing](batch-processing.md) | [Error Handling](error-handling.md) | [Monitoring](monitoring.md) | [Summarization](summarization.md) →

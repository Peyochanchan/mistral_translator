> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Résumés Intelligents

Résumés automatiques, multi-niveaux et multilingues.

## 📝 Résumé Simple

```ruby
summarizer = MistralTranslator::Summarizer.new

summary = summarizer.summarize(
  long_text,
  language: "fr",
  max_words: 100
)
```

## 🌍 Résumé + Traduction

```ruby
# Résume ET traduit en une opération
french_summary = summarizer.summarize_and_translate(
  english_article,
  from: "en",
  to: "fr",
  max_words: 150
)
```

## 📊 Multi-niveaux

```ruby
summaries = summarizer.summarize_tiered(
  article,
  language: "fr",
  short: 50,    # Tweet
  medium: 150,  # Paragraphe
  long: 400     # Article court
)

puts summaries[:short]
puts summaries[:medium]
puts summaries[:long]
```

## 🗺️ Multi-langues

```ruby
results = summarizer.summarize_to_multiple(
  document,
  languages: ["fr", "en", "es"],
  max_words: 200
)
# => { "fr" => "résumé...", "en" => "summary...", "es" => "resumen..." }
```

## 🎯 Styles de Résumé

```ruby
# Différents styles selon l'usage
summarizer.summarize(content, context: "Executive summary, key metrics")
summarizer.summarize(content, context: "Social media, engaging tone")
summarizer.summarize(content, context: "Technical documentation")
```

## 📈 Longueurs Recommandées

**Selon taille du contenu :**

- 0-200 mots → Résumé 30-50 mots
- 200-800 mots → Résumé 50-100 mots
- 800+ mots → Résumé 100-200 mots

**Selon usage :**

- Tweet → 50 mots max
- Meta description → 150 mots max
- Résumé exécutif → 200-400 mots

---

**Advanced Usage Navigation:**
[← Translations](translations.md) | [Batch Processing](batch-processing.md) | [Error Handling](error-handling.md) | [Monitoring](monitoring.md) | [Summarization](summarization.md) →

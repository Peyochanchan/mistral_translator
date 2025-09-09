> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Traductions Avancées

Fonctionnalités avancées : contexte, glossaires, HTML, auto-détection, score de confiance.

## 🎯 Contexte

Améliore la qualité en donnant des indices sur le domaine et l'usage.

```ruby
translator = MistralTranslator::Translator.new

translator.translate(
  "Batterie faible",
  from: "fr",
  to: "en",
  context: "Smartphone notification alert"
)
# => "Battery low"

# vs sans contexte
# => "Low battery"
```

**Contextes utiles :**

- `"Medical documentation"`
- `"E-commerce product page"`
- `"Technical documentation"`
- `"Marketing email"`

## 📚 Glossaires

Garantit la cohérence terminologique.

```ruby
tech_glossary = {
  "IA" => "AI",
  "apprentissage automatique" => "machine learning",
  "données" => "data"
}

translator.translate(
  "L'IA utilise l'apprentissage automatique",
  from: "fr",
  to: "en",
  glossary: tech_glossary
)
# => "AI uses machine learning"
```

## 🎨 Préservation HTML

Traduit le contenu en gardant la structure HTML.

```ruby
html = "<h1>Bienvenue</h1><p>Découvrez nos <strong>services</strong></p>"

translator.translate(
  html,
  from: "fr",
  to: "en",
  preserve_html: true
)
# => "<h1>Welcome</h1><p>Discover our <strong>services</strong></p>"
```

## 🔍 Auto-détection

Détecte automatiquement la langue source.

```ruby
MistralTranslator.translate_auto("Guten Tag", to: "fr")
# => "Bonjour"

MistralTranslator.translate_auto("¿Cómo estás?", to: "en")
# => "How are you?"
```

## 📊 Score de Confiance

Évalue la qualité de la traduction.

```ruby
result = MistralTranslator.translate_with_confidence(
  "Le chat mange",
  from: "fr",
  to: "en"
)

puts result[:translation]  # => "The cat eats"
puts result[:confidence]   # => 0.92
```

**Seuils recommandés :**

- `> 0.9` : Excellente qualité
- `0.7-0.9` : Bonne qualité
- `< 0.7` : Révision recommandée

## 🌍 Multi-langues

Traduit vers plusieurs langues simultanément.

```ruby
translator = MistralTranslator::Translator.new

results = translator.translate_to_multiple(
  "Bienvenue",
  from: "fr",
  to: ["en", "es", "de"],
  use_batch: true  # Optimisation
)

# => { "en" => "Welcome", "es" => "Bienvenido", "de" => "Willkommen" }
```

## 🎛️ Combinaisons Avancées

```ruby
# Contexte + Glossaire + HTML
translator = MistralTranslator::Translator.new

translator.translate(
  "<p>Notre <strong>IA</strong> révolutionne le secteur</p>",
  from: "fr",
  to: "en",
  context: "Technology marketing",
  glossary: { "IA" => "AI" },
  preserve_html: true
)
# => "<p>Our <strong>AI</strong> revolutionizes the industry</p>"
```

---

**Advanced Usage Navigation:**
[← Translations](translations.md) | [Batch Processing](batch-processing.md) | [Error Handling](error-handling.md) | [Monitoring](monitoring.md) | [Summarization](summarization.md) →

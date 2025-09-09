> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/) • [⚡ Advanced Usage](advanced-usage/) • [🛤️ Rails Integration](rails-integration/) • [💻 Examples](../examples/)

# Migration 0.1.0 → 0.2.0

## Résumé

- `context` et `glossary` ne passent plus via l’API publique `MistralTranslator.translate`.
- Utilisez `MistralTranslator::Translator#translate` pour ces options.
- Ajouts notables: rate limiting client, validation d’entrées, nouvelles erreurs, métriques.

## Ce qui change

- Avant (0.1.0) — non supporté par l’API publique:

```ruby
# Peut lever ArgumentError en 0.1.0
MistralTranslator.translate("Batterie faible", from: "fr", to: "en", context: "Smartphone")
```

- Après (0.2.0) — via une instance `Translator`:

```ruby
translator = MistralTranslator::Translator.new
translator.translate("Batterie faible", from: "fr", to: "en", context: "Smartphone")
translator.translate("L'IA...", from: "fr", to: "en", glossary: { "IA" => "AI" })
```

## Migration rapide

1. Rechercher les usages de `MistralTranslator.translate(..., context:/glossary:)`.
2. Remplacer par:

```ruby
translator = MistralTranslator::Translator.new
translator.translate(text, from: from, to: to, context: ctx, glossary: glos)
```

3. Rails (helpers/controllers/services): instancier `translator` avant l’appel.

## Nouvelles protections

- Rate limiting côté client (50 req/min par défaut)
- Validation des entrées (max 50k chars, batch ≤ 20)
- Nouvelles erreurs: `SecurityError`, `RateLimitExceededError`

## Tests & VCR

- Filtrage de la clé API dans les cassettes
- Options VCR par défaut mises à jour

## Références

- Guides mis à jour: Getting Started, Traductions Avancées, Intégration Rails
- Exemple: `examples/basic_usage.rb`

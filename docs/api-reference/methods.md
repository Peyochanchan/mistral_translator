> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Référence des Méthodes API

## Table des Matières

- [Méthodes Principales](#méthodes-principales)
- [Méthodes de Configuration](#méthodes-de-configuration)
- [Méthodes Utilitaires](#méthodes-utilitaires)
- [Méthodes Avancées](#méthodes-avancées)
- [Helpers et Extensions](#helpers-et-extensions)

---

## Méthodes Principales

### `translate(text, from:, to:, **options)`

Traduit un texte d'une langue vers une autre.

**Paramètres:**

- `text` (String) - Le texte à traduire
- `from` (String|Symbol) - Code de langue source (ex: "fr", "en")
- `to` (String|Symbol) - Code de langue cible
- `context` (String, optionnel) - Contexte pour améliorer la traduction
- `glossary` (Hash, optionnel) - Dictionnaire de termes à respecter
- `preserve_html` (Boolean, optionnel) - Préserver les balises HTML

**Retour:** String - Le texte traduit

**Exemple:**

```ruby
MistralTranslator.translate(
  "Bonjour le monde",
  from: "fr",
  to: "en",
  context: "greeting",
  glossary: { "monde" => "world" }
)
# => "Hello world"
```

**Exceptions:**

- `UnsupportedLanguageError` - Langue non supportée
- `EmptyTranslationError` - Traduction vide reçue
- `RateLimitError` - Limite de taux API atteinte

---

### `translate_auto(text, to:, **options)`

Traduit un texte avec détection automatique de la langue source.

**Paramètres:**

- `text` (String) - Le texte à traduire
- `to` (String|Symbol) - Code de langue cible
- `context` (String, optionnel) - Contexte pour la traduction
- `glossary` (Hash, optionnel) - Dictionnaire de termes

**Retour:** String - Le texte traduit

**Exemple:**

```ruby
MistralTranslator.translate_auto("¡Hola mundo!", to: "fr")
# => "Salut le monde !"
```

---

### `translate_to_multiple(text, from:, to:, **options)`

Traduit un texte vers plusieurs langues simultanément.

**Paramètres:**

- `text` (String) - Le texte à traduire
- `from` (String|Symbol) - Code de langue source
- `to` (Array<String>) - Codes des langues cibles
- `use_batch` (Boolean, optionnel) - Utiliser le mode batch pour plus de 3 langues
- `context` (String, optionnel) - Contexte pour la traduction
- `glossary` (Hash, optionnel) - Dictionnaire de termes

**Retour:** Hash - Hash avec les codes de langue comme clés et traductions comme valeurs

**Exemple:**

```ruby
results = MistralTranslator.translate_to_multiple(
  "Hello world",
  from: "en",
  to: %w[fr es de it]
)
# => {
#   "fr" => "Bonjour le monde",
#   "es" => "Hola mundo",
#   "de" => "Hallo Welt",
#   "it" => "Ciao mondo"
# }
```

---

### `translate_batch(texts, from:, to:, **options)`

Traduit plusieurs textes en une fois pour optimiser les performances.

**Paramètres:**

- `texts` (Array<String>) - Les textes à traduire (max 20 éléments)
- `from` (String|Symbol) - Code de langue source
- `to` (String|Symbol) - Code de langue cible
- `context` (String, optionnel) - Contexte commun pour tous les textes
- `glossary` (Hash, optionnel) - Dictionnaire de termes

**Retour:** Hash - Hash avec les index comme clés et traductions comme valeurs

**Exemple:**

```ruby
texts = ["Bonjour", "Merci", "Au revoir"]
results = MistralTranslator.translate_batch(texts, from: "fr", to: "en")
# => {
#   0 => "Hello",
#   1 => "Thank you",
#   2 => "Goodbye"
# }
```

---

## Méthodes de Résumé

### `summarize(text, language:, max_words:, **options)`

Crée un résumé d'un texte dans une langue donnée.

**Paramètres:**

- `text` (String) - Le texte à résumer
- `language` (String|Symbol) - Langue du résumé (défaut: "fr")
- `max_words` (Integer) - Nombre maximum de mots (défaut: 250)
- `style` (String, optionnel) - Style du résumé (formal, casual, academic)
- `context` (String, optionnel) - Contexte du document

**Retour:** String - Le résumé

**Exemple:**

```ruby
article = "Un long article sur Ruby on Rails..."
resume = MistralTranslator.summarize(
  article,
  language: "fr",
  max_words: 100,
  style: "academic"
)
```

---

### `summarize_and_translate(text, from:, to:, max_words:, **options)`

Résume et traduit un texte simultanément.

**Paramètres:**

- `text` (String) - Le texte à résumer et traduire
- `from` (String|Symbol) - Langue source
- `to` (String|Symbol) - Langue cible
- `max_words` (Integer) - Nombre maximum de mots
- `style` (String, optionnel) - Style du résumé
- `context` (String, optionnel) - Contexte du document

**Retour:** String - Le résumé traduit

**Exemple:**

```ruby
result = MistralTranslator.summarize_and_translate(
  "Un long texte en français...",
  from: "fr",
  to: "en",
  max_words: 150
)
```

---

### `summarize_tiered(text, language:, short:, medium:, long:, **options)`

Crée plusieurs résumés de longueurs différentes.

**Paramètres:**

- `text` (String) - Le texte à résumer
- `language` (String|Symbol) - Langue des résumés
- `short` (Integer) - Nombre de mots pour le résumé court
- `medium` (Integer) - Nombre de mots pour le résumé moyen
- `long` (Integer) - Nombre de mots pour le résumé long
- `style` (String, optionnel) - Style des résumés
- `context` (String, optionnel) - Contexte du document

**Retour:** Hash - Hash avec les clés `:short`, `:medium`, `:long`

**Exemple:**

```ruby
resumes = MistralTranslator.summarize_tiered(
  "Un très long article...",
  language: "fr",
  short: 50,
  medium: 150,
  long: 300
)
# => {
#   short: "Résumé court...",
#   medium: "Résumé moyen...",
#   long: "Résumé détaillé..."
# }
```

---

### `summarize_to_multiple(text, languages:, max_words:, **options)`

Crée un résumé dans plusieurs langues.

**Paramètres:**

- `text` (String) - Le texte à résumer
- `languages` (Array<String>) - Langues des résumés
- `max_words` (Integer) - Nombre maximum de mots par résumé

**Retour:** Hash - Hash avec les codes de langue comme clés

**Exemple:**

```ruby
resumes = MistralTranslator.summarize_to_multiple(
  "Un long texte...",
  languages: %w[fr en es],
  max_words: 200
)
# => {
#   "fr" => "Résumé en français...",
#   "en" => "Summary in English...",
#   "es" => "Resumen en español..."
# }
```

---

## Méthodes de Configuration

### `configure { |config| ... }`

Configure la gem avec un bloc.

**Exemple:**

```ruby
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
  config.model = "mistral-small"
  config.retry_delays = [1, 2, 4, 8]
  config.enable_metrics = true
end
```

### `configuration`

Accède à l'objet de configuration actuel.

**Retour:** Configuration - L'instance de configuration

### `reset_configuration!`

Remet la configuration aux valeurs par défaut.

---

## Méthodes Utilitaires

### `supported_locales`

Retourne la liste des codes de langue supportés.

**Retour:** Array<String> - Liste des codes (ex: ["fr", "en", "es"])

### `supported_languages`

Retourne une chaîne formatée des langues supportées.

**Retour:** String - Liste formatée (ex: "fr (français), en (english)")

### `health_check`

Vérifie la connectivité avec l'API Mistral.

**Retour:** Hash - Status et message

- `status` (:ok | :error)
- `message` (String) - Message descriptif

**Exemple:**

```ruby
health = MistralTranslator.health_check
if health[:status] == :ok
  puts "API disponible"
else
  puts "Erreur: #{health[:message]}"
end
```

### `version_info`

Retourne les informations de version détaillées.

**Retour:** Hash - Informations système

- `gem_version` - Version de la gem
- `api_version` - Version de l'API Mistral
- `supported_model` - Modèle supporté
- `ruby_version` - Version Ruby
- `platform` - Plateforme système

---

## Méthodes de Métriques

### `metrics`

Retourne les métriques de performance (si activées).

**Retour:** Hash - Métriques détaillées

- `total_translations` - Nombre total de traductions
- `total_characters` - Nombre total de caractères traités
- `total_duration` - Durée totale des traductions
- `average_translation_time` - Temps moyen par traduction
- `error_rate` - Taux d'erreur en pourcentage
- `translations_by_language` - Décompte par paire de langues

**Exemple:**

```ruby
MistralTranslator.configure { |c| c.enable_metrics = true }

# Après quelques traductions...
metrics = MistralTranslator.metrics
puts "#{metrics[:total_translations]} traductions en #{metrics[:total_duration]}s"
puts "Temps moyen: #{metrics[:average_translation_time]}s"
```

### `MistralTranslator.reset_metrics!`

Remet à zéro toutes les métriques.

---

## Méthodes Avancées

### Classes Principales

#### `MistralTranslator::Translator.new(client: nil)`

Crée une instance de traducteur avec client personnalisé.

**Méthodes d'instance:**

- `translate(text, from:, to:, **options)` - Traduction simple
- `translate_with_confidence(text, from:, to:, **options)` - Avec score de confiance
- `translate_to_multiple(text, from:, to:, **options)` - Multi-langues
- `translate_batch(texts, from:, to:, **options)` - Par lots
- `translate_auto(text, to:, **options)` - Auto-détection

#### `MistralTranslator::Summarizer.new(client: nil)`

Crée une instance de résumeur avec client personnalisé.

**Méthodes d'instance:**

- `summarize(text, language:, max_words:)` - Résumé simple
- `summarize_and_translate(text, from:, to:, max_words:)` - Résumé + traduction
- `summarize_tiered(text, language:, short:, medium:, long:)` - Multi-niveaux
- `summarize_to_multiple(text, languages:, max_words:)` - Multi-langues

#### `MistralTranslator::Client.new(api_key: nil, rate_limiter: nil)`

Client HTTP pour l'API Mistral.

**Méthodes d'instance:**

- `complete(prompt, max_tokens: nil, temperature: nil, context: {})` - Complétion
- `chat(prompt, max_tokens: nil, temperature: nil, context: {})` - Chat
- `translate_batch(requests, batch_size: 5)` - Traduction par lots

---

## Helpers et Extensions

### `MistralTranslator::Helpers`

Module avec des méthodes utilitaires avancées.

#### Méthodes disponibles:

##### `translate_batch_with_fallback(texts, from:, to:, **options)`

Traduction par lots avec stratégies de récupération.

**Options:**

- `fallback_strategy` (:individual) - Stratégie en cas d'échec

##### `translate_with_progress(items, from:, to:, **options, &block)`

Traduction avec callback de progression.

**Exemple:**

```ruby
items = {
  title: "Titre",
  content: "Contenu..."
}

results = MistralTranslator::Helpers.translate_with_progress(
  items,
  from: "fr",
  to: "en"
) do |current, total, key, result|
  puts "#{current}/#{total}: #{key} - #{result[:success] ? 'OK' : 'ERROR'}"
end
```

##### `smart_summarize(text, max_words:, target_language:, **options)`

Résumé intelligent avec détection automatique du format.

##### `translate_multi_style(text, from:, to:, **options)`

Traduction dans plusieurs styles.

**Options:**

- `styles` (Array) - Liste des styles (%i[formal casual academic])

##### `validate_locale_with_suggestions(locale)`

Validation de locale avec suggestions.

**Retour:** Hash

- `valid` (Boolean) - Locale valide ou non
- `locale` (String) - Locale normalisée (si valide)
- `suggestions` (Array) - Suggestions (si invalide)

##### `estimate_translation_cost(text, from:, to:, rate_per_1k_chars:)`

Estimation du coût de traduction.

**Retour:** Hash

- `character_count` - Nombre de caractères
- `estimated_cost` - Coût estimé
- `currency` - Devise ("USD")

##### `setup_rails_integration(**options)`

Configuration automatique pour Rails.

**Options:**

- `api_key` - Clé API (défaut: ENV['MISTRAL_API_KEY'])
- `enable_metrics` (Boolean) - Activer les métriques
- `setup_logging` (Boolean) - Configurer les logs Rails

---

### Extensions String (optionnelles)

Si activées, ajoutent des méthodes à la classe String:

```ruby
# Activation manuelle si souhaitée
String.include(MistralTranslator::StringExtensions)

# Puis utilisation:
"Bonjour".translate_to("en")  # => "Hello"
"Long texte...".summarize(language: "fr", max_words: 50)
```

---

## Adaptateurs Rails

### `MistralTranslator::Adapters`

Support pour les gems d'internationalisation Rails.

#### Adaptateurs disponibles:

- `MobilityAdapter` - Pour la gem Mobility
- `GlobalizeAdapter` - Pour la gem Globalize
- `I18nAttributesAdapter` - Pour les attributs avec suffixes (\_fr, \_en)
- `CustomAdapter` - Pour méthodes personnalisées

#### Usage avec les modèles Rails:

```ruby
# Auto-détection de l'adaptateur
service = MistralTranslator::Adapters::RecordTranslationService.new(
  user,
  [:name, :description],
  source_locale: :fr
)
success = service.translate_to_all_locales

# Ou via les helpers
MistralTranslator::RecordTranslation.translate_record(
  user,
  [:name, :description],
  source_locale: :fr
)
```

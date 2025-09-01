# MistralTranslator

Une gem Ruby pour traduire et résumer du texte en utilisant l'API Mistral AI.

## Installation

Ajoutez cette ligne à votre Gemfile :

```ruby
gem 'mistral_translator'
```

Puis exécutez :

```bash
bundle install
```

Ou installez directement :

```bash
gem install mistral_translator
```

## Configuration

```ruby
require 'mistral_translator'

MistralTranslator.configure do |config|
  config.api_key = 'votre_clé_api_mistral'
  config.api_url = 'https://api.mistral.ai'  # optionnel
  config.model = 'mistral-small'             # optionnel
end
```

### Variables d'environnement

Vous pouvez aussi utiliser des variables d'environnement :

```bash
export MISTRAL_API_KEY=votre_clé_api
export MISTRAL_API_URL=https://api.mistral.ai
```

## Utilisation

### Traduction simple

```ruby
# Traduction de base
result = MistralTranslator.translate("Bonjour le monde", from: 'fr', to: 'en')
# => "Hello world"

# Vers plusieurs langues
results = MistralTranslator.translate_to_multiple(
  "Bonjour le monde", 
  from: 'fr', 
  to: ['en', 'es', 'de']
)
# => { 'en' => "Hello world", 'es' => "Hola mundo", 'de' => "Hallo Welt" }
```

### Traduction en lot

```ruby
texts = ["Bonjour", "Au revoir", "Merci"]
results = MistralTranslator.translate_batch(texts, from: 'fr', to: 'en')
# => { 0 => "Hello", 1 => "Goodbye", 2 => "Thank you" }
```

### Auto-détection de langue

```ruby
result = MistralTranslator.translate_auto("Hello world", to: 'fr')
# => "Bonjour le monde"
```

### Résumés

```ruby
long_text = "Un très long texte à résumer..."

# Résumé simple
summary = MistralTranslator.summarize(long_text, language: 'fr', max_words: 100)

# Résumé avec traduction
summary = MistralTranslator.summarize_and_translate(
  long_text, 
  from: 'fr', 
  to: 'en', 
  max_words: 150
)

# Résumés par niveaux
summaries = MistralTranslator.summarize_tiered(
  long_text,
  language: 'fr',
  short: 50,
  medium: 150, 
  long: 300
)
# => { short: "...", medium: "...", long: "..." }
```

### Extensions String (optionnel)

```ruby
# Activer les extensions String
ENV['MISTRAL_TRANSLATOR_EXTEND_STRING'] = 'true'
require 'mistral_translator'

"Bonjour".mistral_translate(from: 'fr', to: 'en')
# => "Hello"

"Long texte...".mistral_summarize(language: 'fr', max_words: 50)
# => "Résumé..."
```

## Langues supportées

La gem supporte les langues suivantes :
- Français (fr)
- Anglais (en)
- Espagnol (es)
- Portugais (pt)
- Allemand (de)
- Italien (it)
- Néerlandais (nl)
- Russe (ru)
- Japonais (ja)
- Coréen (ko)
- Chinois (zh)
- Arabe (ar)

```ruby
# Vérifier les langues supportées
MistralTranslator.supported_languages
MistralTranslator.locale_supported?('fr') # => true
```

## Gestion d'erreurs

```ruby
begin
  result = MistralTranslator.translate("Hello", from: 'en', to: 'fr')
rescue MistralTranslator::RateLimitError
  puts "Rate limit dépassé, réessayez plus tard"
rescue MistralTranslator::AuthenticationError
  puts "Clé API invalide"
rescue MistralTranslator::UnsupportedLanguageError => e
  puts "Langue non supportée: #{e.language}"
end
```

## Utilisation avancée

### Client personnalisé

```ruby
client = MistralTranslator::Client.new(api_key: 'autre_clé')
translator = MistralTranslator::Translator.new(client: client)
result = translator.translate("Hello", from: 'en', to: 'fr')
```

### Health check

```ruby
status = MistralTranslator.health_check
# => { status: :ok, message: "API connection successful" }
```

## Développement

Après avoir cloné le repo :

```bash
bundle install
bin/setup
```

Pour lancer les tests :

```bash
bundle exec rspec
```

Pour lancer RuboCop :

```bash
bundle exec rubocop
```

## Contribution

Les contributions sont les bienvenues ! Merci de :
1. Forker le projet
2. Créer une branche pour votre feature
3. Commiter vos changements
4. Pousser vers la branche
5. Ouvrir une Pull Request

## Licence

Cette gem est disponible sous la licence MIT.
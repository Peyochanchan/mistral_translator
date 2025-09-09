> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Référence des Erreurs API

## Table des Matières

- [Hiérarchie des Erreurs](#hiérarchie-des-erreurs)
- [Erreurs de Configuration](#erreurs-de-configuration)
- [Erreurs API](#erreurs-api)
- [Erreurs de Traduction](#erreurs-de-traduction)
- [Erreurs de Sécurité](#erreurs-de-sécurité)
- [Gestion des Erreurs](#gestion-des-erreurs)
- [Bonnes Pratiques](#bonnes-pratiques)

---

## Hiérarchie des Erreurs

```
StandardError
└── MistralTranslator::Error
    ├── MistralTranslator::ConfigurationError
    ├── MistralTranslator::ApiError
    │   ├── MistralTranslator::RateLimitError
    │   └── MistralTranslator::AuthenticationError
    ├── MistralTranslator::InvalidResponseError
    ├── MistralTranslator::EmptyTranslationError
    ├── MistralTranslator::UnsupportedLanguageError
    ├── MistralTranslator::SecurityError
    └── MistralTranslator::RateLimitExceededError
```

---

## Erreurs de Configuration

### `MistralTranslator::ConfigurationError`

**Description:** Erreur de configuration de la gem.

**Causes courantes:**

- Clé API manquante ou invalide
- URL d'API incorrecte
- Paramètres de configuration invalides

**Attributs:**

- `message` (String) - Message d'erreur descriptif

**Exemples:**

```ruby
# Clé API manquante
MistralTranslator.configure do |config|
  # config.api_key non définie
end

begin
  MistralTranslator.translate("Hello", from: "en", to: "fr")
rescue MistralTranslator::ConfigurationError => e
  puts "Configuration error: #{e.message}"
  # => "API key is required. Set it with MistralTranslator.configure { |c| c.api_key = 'your_key' }"
end
```

```ruby
# URL d'API incorrecte
MistralTranslator.configure do |config|
  config.api_key = "valid_key"
  config.api_url = "http://invalid-url"  # Doit être HTTPS
end
# => MistralTranslator::ConfigurationError: API URL must use HTTPS protocol
```

**Solutions:**

- Vérifier que la clé API est définie : `ENV['MISTRAL_API_KEY']`
- Utiliser une URL HTTPS valide
- Valider les paramètres de configuration

---

## Erreurs API

### `MistralTranslator::ApiError`

**Description:** Classe de base pour toutes les erreurs API.

**Attributs:**

- `message` (String) - Message d'erreur
- `response` (Net::HTTPResponse, optionnel) - Réponse HTTP brute
- `status_code` (Integer, optionnel) - Code de statut HTTP

**Exemple:**

```ruby
begin
  MistralTranslator.translate("Hello", from: "en", to: "fr")
rescue MistralTranslator::ApiError => e
  puts "API Error: #{e.message}"
  puts "Status: #{e.status_code}" if e.status_code
  puts "Response: #{e.response.body}" if e.response
end
```

---

### `MistralTranslator::AuthenticationError`

**Description:** Erreur d'authentification avec l'API Mistral.

**Hérite de:** `ApiError`

**Code HTTP:** 401

**Causes courantes:**

- Clé API invalide ou expirée
- Clé API non autorisée pour le modèle demandé
- Problème de format de la clé API

**Exemple:**

```ruby
MistralTranslator.configure do |config|
  config.api_key = "invalid_key_12345"
end

begin
  MistralTranslator.translate("Hello", from: "en", to: "fr")
rescue MistralTranslator::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
  # => "Invalid API key"

  # Vérifier votre clé API
  # 1. Connectez-vous à https://console.mistral.ai/
  # 2. Générez une nouvelle clé API
  # 3. Mettez à jour votre configuration
end
```

**Solutions:**

- Vérifier la validité de la clé API sur la console Mistral
- Régénérer une nouvelle clé si nécessaire
- S'assurer que la clé a les permissions nécessaires

---

### `MistralTranslator::RateLimitError`

**Description:** Limite de taux API dépassée.

**Hérite de:** `ApiError`

**Code HTTP:** 429

**Causes courantes:**

- Trop de requêtes envoyées en peu de temps
- Quota API mensuel dépassé
- Limites par minute/heure atteintes

**Exemple:**

```ruby
begin
  # Beaucoup de traductions rapides
  100.times do |i|
    MistralTranslator.translate("Text #{i}", from: "en", to: "fr")
  end
rescue MistralTranslator::RateLimitError => e
  puts "Rate limit exceeded: #{e.message}"

  # La gem fait automatiquement des retry avec backoff exponentiel
  # Mais vous pouvez aussi gérer manuellement :
  puts "Waiting before retry..."
  sleep(60)  # Attendre 1 minute
  retry
end
```

**Gestion automatique:**
La gem inclut un système de retry automatique avec backoff exponentiel :

```ruby
MistralTranslator.configure do |config|
  config.retry_delays = [2, 4, 8, 16, 32]  # Délais en secondes
end
```

**Solutions:**

- Réduire la fréquence des requêtes
- Utiliser `translate_batch` pour les lots
- Ajouter des délais entre les requêtes
- Upgrader votre plan API si nécessaire

---

## Erreurs de Traduction

### `MistralTranslator::InvalidResponseError`

**Description:** Réponse invalide ou malformée de l'API.

**Attributs:**

- `message` (String) - Description de l'erreur
- `raw_response` (String, optionnel) - Réponse brute reçue

**Causes courantes:**

- JSON invalide dans la réponse API
- Structure de réponse inattendue
- Réponse tronquée ou corrompue

**Exemple:**

```ruby
begin
  MistralTranslator.translate("Hello", from: "en", to: "fr")
rescue MistralTranslator::InvalidResponseError => e
  puts "Invalid response: #{e.message}"
  puts "Raw response: #{e.raw_response}" if e.raw_response

  # Cela peut indiquer:
  # - Un problème temporaire avec l'API
  # - Une réponse inattendue du serveur
  # - Un problème de parsing JSON
end
```

**Solutions:**

- Réessayer la requête (souvent temporaire)
- Vérifier la status de l'API Mistral
- Signaler le problème si persistant

---

### `MistralTranslator::EmptyTranslationError`

**Description:** Traduction vide reçue de l'API.

**Causes courantes:**

- Texte source vide ou invalide
- Problème avec le prompt envoyé à l'API
- Réponse API incomplète

**Exemple:**

```ruby
begin
  MistralTranslator.translate("", from: "en", to: "fr")  # Texte vide
rescue MistralTranslator::EmptyTranslationError => e
  puts "Empty translation: #{e.message}"
  # => "Empty translation received from API"
end

# La gem gère automatiquement les textes vides :
result = MistralTranslator.translate("", from: "en", to: "fr")
puts result  # => "" (sans erreur)
```

**Solutions:**

- Vérifier que le texte source n'est pas vide
- S'assurer que le texte contient du contenu traduisible
- Réessayer avec un texte différent

---

### `MistralTranslator::UnsupportedLanguageError`

**Description:** Langue non supportée par la gem.

**Attributs:**

- `language` (String) - Code de langue non supporté

**Langues supportées actuellement:**

```ruby
MistralTranslator.supported_locales
# => ["fr", "en", "es", "pt", "de", "it", "nl", "ru", "mg", "ja", "ko", "zh", "ar"]
```

**Exemple:**

```ruby
begin
  MistralTranslator.translate("Hello", from: "en", to: "klingon")
rescue MistralTranslator::UnsupportedLanguageError => e
  puts "Unsupported language: #{e.message}"
  puts "Language requested: #{e.language}"
  # => "klingon"

  # Obtenir des suggestions :
  suggestions = MistralTranslator::Helpers.validate_locale_with_suggestions("klingon")
  if suggestions[:suggestions].any?
    puts "Did you mean: #{suggestions[:suggestions].join(', ')}?"
  end
end
```

**Solutions:**

- Utiliser `MistralTranslator.supported_locales` pour voir les langues disponibles
- Utiliser le helper de validation avec suggestions
- Normaliser les codes de langue (ex: "français" → "fr")

---

## Erreurs de Sécurité

### `MistralTranslator::SecurityError`

**Description:** Violation de sécurité détectée.

**Causes courantes:**

- Texte dépassant la taille limite (50,000 caractères)
- Contenu potentiellement malveillant détecté
- Tentative d'injection de prompt

**Exemple:**

```ruby
begin
  huge_text = "A" * 100_000  # Texte trop grand
  MistralTranslator.translate(huge_text, from: "en", to: "fr")
rescue ArgumentError => e
  puts "Security limit: #{e.message}"
  # => "Text too long (max 50000 chars)"
end
```

**Solutions:**

- Diviser les textes longs en plusieurs parties
- Valider le contenu avant traduction
- Utiliser `translate_batch` pour les lots importants

---

### `MistralTranslator::RateLimitExceededError`

**Description:** Limite de taux personnalisée dépassée.

**Attributs:**

- `wait_time` (Integer, optionnel) - Temps d'attente suggéré
- `retry_after` (Integer, optionnel) - Timestamp de retry

**Différence avec `RateLimitError`:**

- `RateLimitError` : Limite API Mistral (HTTP 429)
- `RateLimitExceededError` : Limite locale de la gem

**Exemple:**

```ruby
# Configuration du rate limiter local
rate_limiter = MistralTranslator::Security::BasicRateLimiter.new(
  max_requests: 10,
  window_seconds: 60
)

client = MistralTranslator::Client.new(rate_limiter: rate_limiter)

begin
  # Trop de requêtes locales
  15.times { client.complete("Hello") }
rescue MistralTranslator::RateLimitExceededError => e
  puts "Local rate limit exceeded"
  sleep(e.wait_time) if e.wait_time
  retry
end
```

---

## Gestion des Erreurs

### Stratégies de Récupération

#### 1. Retry avec Backoff Exponentiel

```ruby
def safe_translate(text, from:, to:, max_retries: 3)
  retries = 0

  begin
    MistralTranslator.translate(text, from: from, to: to)
  rescue MistralTranslator::RateLimitError, MistralTranslator::ApiError => e
    retries += 1
    if retries <= max_retries
      wait_time = 2 ** retries  # 2, 4, 8 secondes
      puts "Retry #{retries}/#{max_retries} in #{wait_time}s: #{e.message}"
      sleep(wait_time)
      retry
    else
      raise e
    end
  end
end
```

#### 2. Fallback avec Traduction par Défaut

```ruby
def translate_with_fallback(text, from:, to:, fallback: nil)
  MistralTranslator.translate(text, from: from, to: to)
rescue MistralTranslator::Error => e
  puts "Translation failed: #{e.message}"
  fallback || text  # Retourner le fallback ou le texte original
end
```

#### 3. Batch avec Récupération Individuelle

```ruby
def robust_batch_translate(texts, from:, to:)
  begin
    # Essayer le batch d'abord
    MistralTranslator.translate_batch(texts, from: from, to: to)
  rescue MistralTranslator::Error => e
    puts "Batch failed: #{e.message}, falling back to individual translations"

    # Fallback : traduction individuelle
    results = {}
    texts.each_with_index do |text, index|
      begin
        results[index] = MistralTranslator.translate(text, from: from, to: to)
      rescue MistralTranslator::Error => e
        puts "Failed to translate item #{index}: #{e.message}"
        results[index] = text  # Garder l'original en cas d'échec
      end
    end
    results
  end
end
```

#### 4. Circuit Breaker Pattern

```ruby
class TranslationCircuitBreaker
  def initialize(failure_threshold: 5, reset_timeout: 60)
    @failure_threshold = failure_threshold
    @reset_timeout = reset_timeout
    @failure_count = 0
    @last_failure_time = nil
    @state = :closed  # :closed, :open, :half_open
  end

  def translate(text, from:, to:)
    case @state
    when :open
      if Time.now - @last_failure_time > @reset_timeout
        @state = :half_open
      else
        raise MistralTranslator::Error, "Circuit breaker is open"
      end
    end

    begin
      result = MistralTranslator.translate(text, from: from, to: to)
      on_success
      result
    rescue MistralTranslator::Error => e
      on_failure
      raise e
    end
  end

  private

  def on_success
    @failure_count = 0
    @state = :closed
  end

  def on_failure
    @failure_count += 1
    @last_failure_time = Time.now
    @state = :open if @failure_count >= @failure_threshold
  end
end
```

### Logging et Monitoring

#### Configuration des Callbacks d'Erreur

```ruby
MistralTranslator.configure do |config|
  config.on_translation_error = lambda do |from, to, error, attempt, timestamp|
    # Log structuré
    Rails.logger.error({
      event: "translation_error",
      from_language: from,
      to_language: to,
      error_class: error.class.name,
      error_message: error.message,
      attempt_number: attempt,
      timestamp: timestamp
    }.to_json)

    # Notification externe (Sentry, Honeybadger, etc.)
    if defined?(Sentry)
      Sentry.capture_exception(error, extra: {
        from_language: from,
        to_language: to,
        attempt_number: attempt
      })
    end
  end

  config.on_rate_limit = lambda do |from, to, wait_time, attempt, timestamp|
    Rails.logger.warn({
      event: "rate_limit",
      from_language: from,
      to_language: to,
      wait_time: wait_time,
      attempt_number: attempt,
      timestamp: timestamp
    }.to_json)
  end
end
```

#### Métriques d'Erreurs

```ruby
# Analyser le taux d'erreur
metrics = MistralTranslator.metrics
puts "Error rate: #{metrics[:error_rate]}%"
puts "Total errors: #{metrics[:errors_count]}"

# Alertes basées sur les métriques
if metrics[:error_rate] > 10.0  # Plus de 10% d'erreurs
  # Envoyer une alerte
  AlertService.notify("High translation error rate: #{metrics[:error_rate]}%")
end
```

---

## Bonnes Pratiques

### 1. Gestion Proactive des Erreurs

```ruby
# ✅ Bon : Gestion spécifique des erreurs
begin
  translation = MistralTranslator.translate(text, from: "fr", to: "en")
rescue MistralTranslator::UnsupportedLanguageError => e
  # Gérer les langues non supportées
  translation = handle_unsupported_language(text, e.language)
rescue MistralTranslator::RateLimitError => e
  # Gérer les rate limits
  translation = handle_rate_limit(text, e)
rescue MistralTranslator::AuthenticationError => e
  # Gérer les problèmes d'auth
  translation = handle_auth_error(text, e)
rescue MistralTranslator::Error => e
  # Fallback général pour toutes les autres erreurs
  translation = handle_general_error(text, e)
end

# ❌ Mauvais : Catch-all trop large
begin
  translation = MistralTranslator.translate(text, from: "fr", to: "en")
rescue StandardError => e
  # Trop générique, peut cacher d'autres problèmes
  translation = text
end
```

### 2. Validation des Entrées

```ruby
def safe_translate(text, from:, to:, **options)
  # Validation préalable
  raise ArgumentError, "Text cannot be nil" if text.nil?
  raise ArgumentError, "Text too long" if text.length > 50_000

  # Validation des langues avec suggestions
  from_validation = MistralTranslator::Helpers.validate_locale_with_suggestions(from)
  unless from_validation[:valid]
    raise MistralTranslator::UnsupportedLanguageError,
          "Source language '#{from}' not supported. Suggestions: #{from_validation[:suggestions].join(', ')}"
  end

  # Traduction sécurisée
  MistralTranslator.translate(text, from: from, to: to, **options)
end
```

### 3. Monitoring et Alertes

```ruby
class TranslationMonitor
  def self.monitor_translation(&block)
    start_time = Time.now
    result = yield
    duration = Time.now - start_time

    # Log de performance
    if duration > 30.0  # Plus de 30 secondes
      Rails.logger.warn("Slow translation detected: #{duration}s")
    end

    result
  rescue MistralTranslator::Error => e
    # Log d'erreur avec contexte
    Rails.logger.error({
      event: "translation_failure",
      error: e.class.name,
      message: e.message,
      duration: Time.now - start_time
    }.to_json)

    raise e
  end
end

# Usage
translation = TranslationMonitor.monitor_translation do
  MistralTranslator.translate("Hello", from: "en", to: "fr")
end
```

### 4. Tests des Scenarios d'Erreur

```ruby
# Dans vos specs RSpec
describe "error handling" do
  it "handles rate limit gracefully" do
    allow(MistralTranslator::Client).to receive(:new).and_raise(
      MistralTranslator::RateLimitError.new("Rate limit exceeded")
    )

    expect {
      MistralTranslator.translate("Hello", from: "en", to: "fr")
    }.to raise_error(MistralTranslator::RateLimitError)
  end

  it "provides fallback for unsupported languages" do
    result = translate_with_fallback(
      "Hello",
      from: "klingon",
      to: "fr",
      fallback: "Hello"
    )
    expect(result).to eq("Hello")
  end
end
```

Cette approche robuste de gestion des erreurs garantit que votre application reste stable même en cas de problèmes avec l'API de traduction.

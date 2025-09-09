# Sécurité - MistralTranslator

## 🔒 Améliorations de sécurité implémentées

### 1. Validation des entrées utilisateur

#### Validation basique (par défaut)

- **Longueur des textes** : Limite à 50 000 caractères maximum
- **Textes vides** : Acceptés et retournés comme chaîne vide (cas d'usage légitime)
- **Validation des batches** : Maximum 20 textes par batch
- **Validation des paramètres** : Vérification des types et valeurs

#### Protection contre les attaques courantes

- **Injection de code** : Détection des patterns dangereux
- **Scripts malveillants** : Filtrage des balises HTML/JavaScript
- **Injection SQL** : Détection des patterns SQL malveillants
- **Traversal de chemins** : Protection contre les accès non autorisés

### 2. Rate Limiting côté client

#### Fonctionnalités

- **Limite par défaut** : 50 requêtes par minute
- **Configuration flexible** : Limites personnalisables
- **Thread-safe** : Protection contre les conditions de course
- **Attente intelligente** : Délai automatique quand la limite est atteinte

#### Configuration

```ruby
# Via variables d'environnement
MISTRAL_RATE_LIMIT_MAX_REQUESTS=100
MISTRAL_RATE_LIMIT_WINDOW=60

# Via code
rate_limiter = MistralTranslator::Security::BasicRateLimiter.new(
  max_requests: 100,
  window_seconds: 60
)
```

### 3. Gestion sécurisée des erreurs

#### Nouvelles exceptions

- `SecurityError` : Violations de sécurité détectées
- `RateLimitExceededError` : Limite de taux dépassée

#### Messages d'erreur sécurisés

- Aucune exposition d'informations sensibles
- Messages d'erreur génériques pour éviter les fuites

### 4. Optimisation de la taille

#### Réduction significative

- **Avant** : ~4000+ lignes avec validation complète
- **Après** : 3197 lignes avec sécurité essentielle
- **Gain** : ~20% de réduction de taille

#### Architecture modulaire

- Module de sécurité optionnel et léger
- Validation basique par défaut
- Possibilité d'extension future

## 🛡️ Utilisation sécurisée

### Configuration recommandée

```ruby
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
  config.enable_metrics = true

  # Callbacks de sécurité
  config.on_translation_error = lambda do |from, to, error, attempt, timestamp|
    Rails.logger.error "[Security] Translation failed: #{error.class.name}"
  end
end
```

### Cas d'usage légitimes

- **Textes vides** : Acceptés automatiquement (retournent une chaîne vide)
- **Même langue source/cible** : Retourne le texte original sans appel API
- **Validation permissive** : Focus sur la sécurité sans bloquer l'usage normal

### Bonnes pratiques

1. **Validation côté client** : Toujours valider les entrées avant l'envoi
2. **Gestion des erreurs** : Capturer et logger les erreurs de sécurité
3. **Monitoring** : Surveiller les tentatives de rate limiting
4. **Mise à jour** : Maintenir la gem à jour pour les dernières corrections

## 🔍 Tests de sécurité

### Couverture des tests

- Validation des entrées malveillantes
- Tests de rate limiting
- Vérification de la thread-safety
- Tests d'encodage et de format

### Exécution des tests

```bash
# Tests de sécurité uniquement
bundle exec rspec spec/mistral_translator/security_spec.rb

# Tests de sécurité existants
bundle exec rspec spec/mistral_translator/security_spec.rb
```

## 📊 Métriques de sécurité

### Indicateurs surveillés

- Nombre de requêtes bloquées par validation
- Fréquence des rate limits
- Types d'erreurs de sécurité
- Temps de réponse moyen

### Accès aux métriques

```ruby
# Métriques globales
MistralTranslator.metrics

# Réinitialisation
MistralTranslator.reset_metrics!
```

## 🚨 Signaler des vulnérabilités

Si vous découvrez une vulnérabilité de sécurité :

1. **Ne pas** ouvrir d'issue publique
2. Envoyer un email à : security@mistral-translator.dev
3. Inclure : description, étapes de reproduction, impact

## 📝 Changelog de sécurité

### Version 0.2.0

- ✅ Validation basique des entrées
- ✅ Rate limiting côté client
- ✅ Nouvelles exceptions de sécurité
- ✅ Optimisation de la taille de la gem
- ✅ Tests de sécurité complets

---

_Cette documentation est mise à jour à chaque amélioration de sécurité._

{% include_relative _includes/nav.md %}

# Documentation MistralTranslator

Bienvenue dans la documentation complète de **MistralTranslator**, une gem Ruby puissante pour la traduction et la synthèse de texte utilisant l'API Mistral AI.

## 🚀 Démarrage Rapide

```ruby
# Installation
gem 'mistral_translator'

# Configuration
MistralTranslator.configure { |c| c.api_key = ENV['MISTRAL_API_KEY'] }

# Usage
result = MistralTranslator.translate("Bonjour le monde", from: "fr", to: "en")
# => "Hello world"
```

## 📚 Guide de Documentation

### 🎯 Pour Commencer

| Fichier                                                | Description                                     | Niveau   |
| ------------------------------------------------------ | ----------------------------------------------- | -------- |
| [Installation](installation.md)                        | Installation de la gem et configuration de base | Débutant |
| [Guide de Démarrage](getting-started.md)               | Premiers pas avec exemples simples              | Débutant |
| [Exemples de Base](../examples/basic_usage.rb)         | Code commenté pour débuter                      | Débutant |
| [Migration 0.1.0 → 0.2.0](migration-0.1.0-to-0.2.0.md) | Changements clés et guide de migration          | Tous     |

### ⚡ Fonctionnalités Avancées

| Fichier                                                  | Description                                    | Contenu Principal                                 |
| -------------------------------------------------------- | ---------------------------------------------- | ------------------------------------------------- |
| [Traductions Avancées](advanced-usage/translations.md)   | Contexte, glossaires, HTML, auto-détection     | `translate_with_confidence()`, `translate_auto()` |
| [Traitement par Lot](advanced-usage/batch-processing.md) | Optimisation batch, multi-langues, progression | `translate_batch()`, `translate_to_multiple()`    |
| [Résumés Intelligents](advanced-usage/summarization.md)  | Multi-niveaux, multi-langues, Rails            | `summarize()`, `summarize_tiered()`               |
| [Gestion des Erreurs](advanced-usage/error-handling.md)  | Retry, circuit breaker, fallback strategies    | Patterns de robustesse                            |
| [Monitoring](advanced-usage/monitoring.md)               | Métriques, dashboard, alertes                  | Analytics et observabilité                        |

### 🛤️ Intégration Rails

| Fichier                                                 | Description                             | Gems Supportées           |
| ------------------------------------------------------- | --------------------------------------- | ------------------------- |
| [Configuration Rails](rails-integration/setup.md)       | Initializers, environnements, callbacks | Rails 7+                  |
| [Adaptateurs de Modèles](rails-integration/adapters.md) | Intégration transparente avec gems I18n | Mobility, Globalize, I18n |
| [Jobs Asynchrones](rails-integration/jobs.md)           | Traduction en arrière-plan              | Sidekiq, ActiveJob        |
| [Controllers & API](rails-integration/controllers.md)   | Endpoints, dashboard admin              | REST API, Admin UI        |

### 📖 Référence API

| Fichier                                         | Description                         | Usage                         |
| ----------------------------------------------- | ----------------------------------- | ----------------------------- |
| [Configuration](api-reference/configuration.md) | Toutes les options de configuration | `MistralTranslator.configure` |
| [Méthodes](api-reference/methods.md)            | Documentation complète des méthodes | API publique                  |
| [Erreurs](api-reference/errors.md)              | Types d'erreurs et codes de gestion | `rescue` patterns             |
| [Callbacks](api-reference/callbacks.md)         | Événements et hooks personnalisés   | Monitoring custom             |

### 💻 Exemples Pratiques

| Fichier                                             | Description                       | Cas d'Usage     |
| --------------------------------------------------- | --------------------------------- | --------------- |
| [Usage de Base](../examples/basic_usage.rb)         | Script simple avec commentaires   | Premier projet  |
| [Modèle Rails](../examples/rails-model.rb)          | Modèle complet avec traductions   | App Rails       |
| [Job de Traitement](../examples/batch-job.rb)       | Job Sidekiq pour batch            | Production      |
| [Setup Monitoring](../examples/monitoring-setup.rb) | Configuration complète monitoring | Ops & Analytics |

---

## 🎯 Cas d'Usage Principaux

### 🌐 **Applications Multilingues**

- E-commerce international
- Sites web multilingues
- Applications SaaS globales
- Documentation technique

### 📝 **Traitement de Contenu**

- Résumés automatiques d'articles
- Synthèse de rapports
- Newsletter multilingues
- Support client automatisé

### 🔧 **Intégration Système**

- CMS multilingues
- APIs de traduction
- Workflows de contenu
- Automation marketing

---

## 🏃‍♂️ Parcours Recommandés

### **👶 Débutant - Premiers Pas**

1. [Installation](installation.md) - Installer et configurer
2. [Guide de Démarrage](getting-started.md) - Premiers exemples
3. [Exemples de Base](../examples/basic_usage.rb) - Code pratique

### **⚡ Développeur Rails**

1. [Configuration Rails](rails-integration/setup.md) - Setup Rails
2. [Adaptateurs](rails-integration/adapters.md) - Mobility/Globalize
3. [Modèle Rails](../examples/rails-model.rb) - Exemple complet

### **🚀 Usage Production**

1. [Gestion des Erreurs](advanced-usage/error-handling.md) - Robustesse
2. [Monitoring](advanced-usage/monitoring.md) - Observabilité
3. [Jobs Asynchrones](rails-integration/jobs.md) - Scalabilité

### **📊 Analytics & Ops**

1. [Monitoring](advanced-usage/monitoring.md) - Métriques
2. [Setup Monitoring](../examples/monitoring-setup.rb) - Configuration
3. [API Référence](api-reference/configuration.md) - Tuning avancé

---

## 🆘 Aide et Support

- **🐛 Problème ?** → Consultez [Gestion des Erreurs](advanced-usage/error-handling.md)
- **⚙️ Configuration ?** → Voir [API Configuration](api-reference/configuration.md)
- **🛤️ Rails ?** → Section [Intégration Rails](rails-integration/setup.md)
- **📈 Performance ?** → Guide [Monitoring](advanced-usage/monitoring.md)

## 🎯 Navigation Rapide

**Recherche par fonctionnalité :**

- **Traduction simple** → [Getting Started](getting-started.md#traduction-simple)
- **Traduction HTML** → [Traductions Avancées](advanced-usage/translations.md#html-preservation)
- **Résumés** → [Résumés Intelligents](advanced-usage/summarization.md)
- **Batch processing** → [Traitement par Lot](advanced-usage/batch-processing.md)
- **Intégration Mobility** → [Adaptateurs](rails-integration/adapters.md#mobility)
- **Jobs Sidekiq** → [Jobs Asynchrones](rails-integration/jobs.md#sidekiq)
- **Dashboard admin** → [Controllers](rails-integration/controllers.md#dashboard)

**Par niveau de complexité :**

- 🟢 **Facile** : Installation, Getting Started, Exemples
- 🟡 **Moyen** : Traductions Avancées, Rails Setup, Jobs
- 🔴 **Avancé** : Error Handling, Monitoring, API Référence

---

_📝 Cette documentation est maintenue et mise à jour régulièrement. Pour des suggestions d'amélioration, n'hésitez pas à contribuer !_

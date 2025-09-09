# MistralTranslator

> 🚀 Une gem Ruby puissante pour la traduction et la synthèse de texte utilisant l'API Mistral AI, avec support avancé pour Rails.

[![Gem Version](https://badge.fury.io/rb/mistral_translator.svg)](https://badge.fury.io/rb/mistral_translator)
[![Ruby](https://github.com/username/mistral_translator/actions/workflows/ruby.yml/badge.svg)](https://github.com/username/mistral_translator/actions/workflows/ruby.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ⚡ Installation Rapide

```ruby
# Gemfile
gem 'mistral_translator'

# Configuration
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
end
```

## 🎯 Usage de Base

```ruby
# Traduction simple
result = MistralTranslator.translate("Bonjour le monde", from: "fr", to: "en")
# => "Hello world"

# Traduction avec contexte
result = MistralTranslator.translate(
  "Le produit est disponible",
  from: "fr", to: "en",
  context: "E-commerce website",
  glossary: { "produit" => "item" }
)
# => "The item is available"

# Résumé intelligent
summary = MistralTranslator.summarize(
  "Long article content...",
  language: "fr",
  max_words: 100
)

# Intégration Rails
class Article < ApplicationRecord
  translates :title, :content  # Mobility/Globalize

  def translate_to_all_languages!
    MistralTranslator::RecordTranslation.translate_mobility_record(
      self, [:title, :content], source_locale: I18n.locale
    )
  end
end
```

## 🌟 Fonctionnalités Principales

- ✅ **Traduction intelligente** avec contexte et glossaires personnalisés
- ✅ **Intégration Rails native** (Mobility, Globalize, I18n)
- ✅ **Traitement par lot optimisé** pour de gros volumes
- ✅ **Résumés multi-niveaux** et multi-langues
- ✅ **Gestion d'erreurs robuste** avec retry automatique et fallback
- ✅ **Monitoring complet** avec métriques et dashboard
- ✅ **Jobs asynchrones** pour traitement en arrière-plan
- ✅ **Rate limiting** et sécurité intégrés

## 📚 Documentation Complète

| Section                                          | Description                          |
| ------------------------------------------------ | ------------------------------------ |
| 📖 [**Documentation Complète**](docs/)           | Guide complet avec tous les exemples |
| 🚀 [Installation & Config](docs/installation.md) | Setup détaillé et configuration      |
| 👶 [Guide de Démarrage](docs/getting-started.md) | Premiers pas avec exemples           |
| ⚡ [Usage Avancé](docs/advanced-usage/)          | Fonctionnalités avancées             |
| 🛤️ [Intégration Rails](docs/rails-integration/)  | Setup Rails complet                  |
| 📊 [API Référence](docs/api-reference/)          | Documentation technique              |
| 💻 [Exemples Pratiques](examples/)               | Code prêt à utiliser                 |

## 🏃‍♂️ Démarrage selon votre Profil

**🆕 Nouveau avec la gem ?**  
→ [Installation](docs/installation.md) → [Guide de Démarrage](docs/getting-started.md)

**🛤️ Projet Rails existant ?**  
→ [Config Rails](docs/rails-integration/setup.md) → [Adaptateurs](docs/rails-integration/adapters.md)

**🚀 Déploiement Production ?**  
→ [Gestion Erreurs](docs/advanced-usage/error-handling.md) → [Monitoring](docs/advanced-usage/monitoring.md)

## 🌍 Langues Supportées

`fr` `en` `es` `pt` `de` `it` `nl` `ru` `mg` `ja` `ko` `zh` `ar`

## 🔧 Configuration Rapide Rails

```ruby
# config/initializers/mistral_translator.rb
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
  config.enable_metrics = Rails.env.production?
  config.setup_rails_logging if Rails.env.development?

  # Callbacks pour monitoring
  config.on_translation_complete = ->(from, to, orig_len, trans_len, duration) {
    Rails.logger.info "✅ #{from}→#{to} completed in #{duration.round(2)}s"
  }
end
```

## 📊 Exemple Avancé

```ruby
# Traduction batch avec progression et monitoring
texts = ["Texte 1", "Texte 2", "Texte 3"]

results = MistralTranslator::Helpers.translate_with_progress(
  texts.each_with_index.to_h,
  from: "fr", to: "en"
) do |current, total, key, result|
  puts "Progress: #{(current.to_f/total*100).round(1)}% - #{key}"
end

# Résumés multi-niveaux
summaries = MistralTranslator.summarize_tiered(
  long_content,
  language: "fr",
  short: 50,    # Version tweet
  medium: 150,  # Version paragraphe
  long: 400     # Version article
)
```

## 🤝 Contribution

Les contributions sont les bienvenues ! Voir [CONTRIBUTING.md](CONTRIBUTING.md).

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit (`git commit -m 'Add AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 📝 Changelog

Voir [CHANGELOG.md](CHANGELOG.md) pour l'historique des versions.

## 📞 Support & Community

- 📖 [Documentation](docs/)
- 🐛 [Issues](../../issues)
- 💬 [Discussions](../../discussions)
- 📧 Email: support@votre-domain.com

## ⚖️ License

Distribué sous la licence MIT. Voir [LICENSE](LICENSE) pour plus d'informations.

---

<div align="center">
  <sub>Built with ❤️ by <a href="https://github.com/peyochanchan">@Peyochanchan</a></sub>
</div>

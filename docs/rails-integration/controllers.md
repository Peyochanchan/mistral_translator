> **Navigation :** [🏠 Home](README.md) • [📖 API Reference](api-reference/methods.md) • [⚡ Advanced Usage](advanced-usage/translations.md) • [🛤️ Rails Integration](rails-integration/setup.md)

---

# Controllers et API

Endpoints pour traduction et interface d'administration.

## API Endpoint

```ruby
class Api::TranslationsController < ApplicationController
  def create
    translator = MistralTranslator::Translator.new
    result = translator.translate(
      params[:text],
      from: params[:from],
      to: params[:to],
      context: params[:context]
    )

    render json: { translation: result }
  rescue MistralTranslator::Error => e
    render json: { error: e.message }, status: 422
  end
end
```

## Traduction de Modèles

```ruby
class Admin::TranslationsController < ApplicationController
  def translate_record
    model = params[:model].constantize.find(params[:id])

    TranslateRecordJob.perform_later(
      params[:model],
      params[:id],
      params[:fields]
    )

    redirect_back fallback_location: root_path,
                  notice: "Traduction en cours..."
  end
end
```

## Dashboard Métriques

```ruby
class Admin::MetricsController < ApplicationController
  def show
    @metrics = MistralTranslator.metrics
    @recent_activity = translation_activity_summary
  end

  private

  def translation_activity_summary
    # Vos métriques business selon vos besoins
  end
end
```

## Sélecteur de Langue

```ruby
class ApplicationController < ActionController::Base
  around_action :switch_locale

  private

  def switch_locale(&block)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &block)
  end

  def default_url_options
    { locale: I18n.locale }
  end
end
```

## Patterns Recommandés

**API Endpoints :**

- Rate limiting pour éviter l'abus
- Cache des traductions fréquentes
- Validation des paramètres d'entrée

**Admin Interface :**

- Actions en lot pour traduction de modèles
- Queue status et progression
- Métriques d'usage et coûts

**Frontend :**

- Traduction en temps réel via AJAX
- Fallback sur texte original si échec
- Indicateurs de loading/progression

---

**Rails Integration Navigation:**
[← Setup](rails-integration/setup.md) | [Adapters](rails-integration/adapters.md) | [Jobs](rails-integration/jobs.md) | [Controllers](rails-integration/controllers.md) →

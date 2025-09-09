{% include_relative _includes/nav.md %}

# Configuration Rails

Intégration complète de MistralTranslator avec Ruby on Rails.

## Initializer Rails

```ruby
# config/initializers/mistral_translator.rb
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']
  config.enable_metrics = Rails.env.production?

  case Rails.env
  when 'development'
    config.setup_rails_logging
    config.retry_delays = [1, 2, 4]

  when 'production'
    config.retry_delays = [2, 4, 8, 16, 32]

    # Callbacks production
    config.on_translation_error = ->(from, to, error, attempt, timestamp) {
      if defined?(Sentry) && attempt > 2
        Sentry.capture_exception(error, extra: {
          translation: { from: from, to: to, attempt: attempt }
        })
      end
    }

    config.on_translation_complete = ->(from, to, orig_len, trans_len, duration) {
      if defined?(StatsD)
        StatsD.timing('mistral.translation.duration', duration * 1000)
        StatsD.increment('mistral.translation.success')
      end
    }
  end
end
```

## Helper Global

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  def safe_translate(text, to:, context: nil)
    return text if text.blank?
    return text if I18n.locale.to_s == to.to_s

    translator = MistralTranslator::Translator.new
    translator.translate(
      text,
      from: I18n.locale.to_s,
      to: to.to_s,
      context: context
    )
  rescue MistralTranslator::Error => e
    Rails.logger.error "Translation failed: #{e.message}"
    text
  end

  def translate_with_cache(text, to:, **options)
    cache_key = "translation:#{Digest::MD5.hexdigest(text)}:#{I18n.locale}:#{to}"

    Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      safe_translate(text, to: to, **options)
    end
  end
end
```

## Service de Traduction

```ruby
# app/services/translation_service.rb
class TranslationService
  def self.translate_model(record, fields, target_locales = nil)
    target_locales ||= I18n.available_locales - [I18n.locale]

    success_count = 0
    error_count = 0

    target_locales.each do |locale|
      begin
        translate_fields_for_locale(record, fields, locale)
        success_count += 1
      rescue MistralTranslator::Error => e
        Rails.logger.error "Translation failed for #{locale}: #{e.message}"
        error_count += 1
      end
    end

    { success: success_count, errors: error_count }
  end

  private

  def self.translate_fields_for_locale(record, fields, locale)
    Array(fields).each do |field|
      source_value = record.send("#{field}_#{I18n.locale}")
      next if source_value.blank?

      translator = MistralTranslator::Translator.new
      translated = translator.translate(
        source_value,
        from: I18n.locale.to_s,
        to: locale.to_s,
        context: "#{record.class.name} #{field}"
      )

      record.send("#{field}_#{locale}=", translated)
    end

    record.save!
  end
end
```

## Concern pour Modèles

```ruby
# app/models/concerns/translatable.rb
module Translatable
  extend ActiveSupport::Concern

  included do
    after_save :auto_translate, if: :should_auto_translate?
  end

  class_methods do
    def translatable_fields(*fields)
      @translatable_fields = fields
    end

    def get_translatable_fields
      @translatable_fields || []
    end
  end

  def translate_to_all_locales
    return false if self.class.get_translatable_fields.empty?

    result = TranslationService.translate_model(
      self,
      self.class.get_translatable_fields
    )

    Rails.logger.info "Translated #{result[:success]} locales, #{result[:errors]} errors"
    result[:errors] == 0
  end

  private

  def should_auto_translate?
    Rails.env.production? &&
    self.class.get_translatable_fields.any? { |field| saved_change_to_attribute?("#{field}_#{I18n.locale}") }
  end

  def auto_translate
    TranslateModelJob.perform_later(self.class.name, id)
  end
end
```

## Exemple d'Usage

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  include Translatable

  translatable_fields :title, :content, :summary

  # Méthode manuelle
  def translate_title_to(locale)
    translator = MistralTranslator::Translator.new
    translator.translate(
      title,
      from: I18n.locale.to_s,
      to: locale.to_s,
      context: "Blog article title"
    )
  rescue MistralTranslator::Error
    title
  end
end

# Usage
article = Article.create!(title: "Mon article", content: "Contenu...")
article.translate_to_all_locales
```

## Job Asynchrone

```ruby
# app/jobs/translate_model_job.rb
class TranslateModelJob < ApplicationJob
  queue_as :translations

  def perform(model_class, record_id)
    model = model_class.constantize
    record = model.find(record_id)

    result = TranslationService.translate_model(record, model.get_translatable_fields)

    Rails.logger.info "Translation job completed: #{result[:success]} success, #{result[:errors]} errors"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Record not found: #{model_class}##{record_id}"
  rescue => e
    Rails.logger.error "Translation job failed: #{e.message}"
    raise e
  end
end
```

## Variables d'Environnement

```ruby
# .env.development
MISTRAL_API_KEY=your_dev_key_here

# .env.production
MISTRAL_API_KEY=your_prod_key_here

# config/application.yml (Figaro)
development:
  MISTRAL_API_KEY: your_dev_key

production:
  MISTRAL_API_KEY: your_prod_key
```

## Vues et Formulaires

```erb
<!-- app/views/articles/show.html.erb -->
<div class="article">
  <h1><%= @article.title %></h1>

  <!-- Sélecteur de langue -->
  <div class="language-selector">
    <% I18n.available_locales.each do |locale| %>
      <%= link_to locale.upcase,
          article_path(@article, locale: locale),
          class: ("active" if I18n.locale == locale) %>
    <% end %>
  </div>

  <!-- Traduction à la demande -->
  <% if I18n.locale != I18n.default_locale %>
    <div class="translation-info">
      <%= translate_with_cache(@article.content, to: I18n.locale,
                              context: "Blog article content") %>
    </div>
  <% else %>
    <div class="content">
      <%= @article.content %>
    </div>
  <% end %>
</div>
```

## Configuration Avancée

```ruby
# config/initializers/mistral_translator.rb
MistralTranslator.configure do |config|
  config.api_key = ENV['MISTRAL_API_KEY']

  # Optimisation Rails
  config.enable_metrics = true
  config.default_max_tokens = 4000

  # Cache intelligent des traductions
  config.on_translation_complete = ->(from, to, orig_len, trans_len, duration) {
    # Statistiques dans le cache Rails
    Rails.cache.increment("translation_count_#{Date.current}", 1, expires_in: 1.day)

    # Log des traductions coûteuses
    if orig_len > 1000
      Rails.logger.info "Large translation: #{orig_len} chars in #{duration.round(2)}s"
    end
  }

  # Intégration avec ActiveSupport::Notifications
  config.on_translation_start = ->(from, to, length, timestamp) {
    ActiveSupport::Notifications.instrument("translation.mistral", {
      from: from, to: to, length: length
    })
  }
end

# Écouter les notifications
ActiveSupport::Notifications.subscribe "translation.mistral" do |name, start, finish, id, payload|
  Rails.logger.info "Translation notification: #{payload}"
end
```

## Tests Rails

```ruby
# spec/support/mistral_translator.rb
RSpec.configure do |config|
  config.before(:suite) do
    MistralTranslator.configure do |c|
      c.api_key = 'test-key'
      c.enable_metrics = false
    end
  end
end

# spec/models/article_spec.rb
require 'rails_helper'

RSpec.describe Article do
  before do
    allow(MistralTranslator).to receive(:translate).and_return("Mocked translation")
  end

  describe '#translate_to_all_locales' do
    it 'translates all fields to available locales' do
      article = create(:article, title: "Test", content: "Content")

      expect(MistralTranslator).to receive(:translate).twice
      result = article.translate_to_all_locales

      expect(result).to be true
    end
  end
end
```

---

**Prochaines étapes :** [Adaptateurs](adapters.md) | [Jobs Asynchrones](jobs.md)

#!/usr/bin/env ruby
# frozen_string_literal: true

# Exemple d'intégration MistralTranslator avec des modèles Rails
# Usage: rails runner examples/rails-model.rb

# Arrêter si le script n'est pas exécuté dans un contexte Rails
unless defined?(Rails)
  warn "Ce script est destiné à être exécuté dans un projet Rails. Utilisez: rails runner examples/rails-model.rb"
  exit 1
end

# Configuration initiale
MistralTranslator.configure do |config|
  config.api_key = ENV.fetch("MISTRAL_API_KEY", nil)
  config.enable_metrics = true
  config.setup_rails_logging
end

# === EXEMPLE 1: Modèle avec Mobility ===

class Article < ApplicationRecord
  extend Mobility

  translates :title, :content, :description, backend: :table

  # Callbacks pour traduction automatique
  after_create :translate_to_all_locales, if: :should_auto_translate?
  after_update :retranslate_if_changed, if: :should_auto_translate?

  def translate_to_all_locales(source_locale: I18n.locale)
    MistralTranslator::RecordTranslation.translate_mobility_record(
      self,
      %i[title content description],
      source_locale: source_locale
    )
  end

  def translate_to(target_locales, source_locale: I18n.locale)
    Array(target_locales).each do |target_locale|
      next if source_locale.to_s == target_locale.to_s

      translatable_fields.each do |field|
        source_text = public_send("#{field}_#{source_locale}")
        next if source_text.blank?

        translated = MistralTranslator.translate(
          source_text,
          from: source_locale,
          to: target_locale,
          context: "article content"
        )

        public_send("#{field}_#{target_locale}=", translated)
      end
    end

    save! if changed?
  end

  def estimate_translation_cost
    total_chars = translatable_fields.sum do |field|
      content = public_send("#{field}_#{I18n.default_locale}")
      content&.length || 0
    end

    target_locales = I18n.available_locales - [I18n.default_locale]

    {
      character_count: total_chars,
      target_languages: target_locales.size,
      estimated_cost: (total_chars * target_locales.size / 1000.0) * 0.02,
      currency: "USD"
    }
  end

  private

  def should_auto_translate?
    Rails.env.production? && ENV["AUTO_TRANSLATE"] == "true"
  end

  def retranslate_if_changed
    changed_fields = translatable_fields.select do |field|
      saved_change_to_attribute?("#{field}_#{I18n.default_locale}")
    end

    return if changed_fields.empty?

    TranslationJob.perform_later(self, changed_fields)
  end

  def translatable_fields
    %i[title content description]
  end
end

# === EXEMPLE 2: Modèle avec attributs I18n simples ===

class Product < ApplicationRecord
  # Colonnes: name_fr, name_en, description_fr, description_en, etc.

  include MistralTranslator::Helpers::RecordHelpers

  SUPPORTED_LOCALES = %w[fr en es de].freeze
  TRANSLATABLE_FIELDS = %w[name description features].freeze

  def translate_all!(source_locale: "fr")
    target_locales = SUPPORTED_LOCALES - [source_locale]

    TRANSLATABLE_FIELDS.each do |field|
      source_text = public_send("#{field}_#{source_locale}")
      next if source_text.blank?

      target_locales.each do |target_locale|
        translated = MistralTranslator.translate(
          source_text,
          from: source_locale,
          to: target_locale,
          context: "e-commerce product",
          glossary: product_glossary
        )

        public_send("#{field}_#{target_locale}=", translated)
      end
    end

    save!
  end

  def translate_field(field, from:, to:)
    source_text = public_send("#{field}_#{from}")
    return if source_text.blank?

    translated = MistralTranslator.translate(
      source_text,
      from: from,
      to: to,
      context: "product #{field}",
      glossary: product_glossary
    )

    update!("#{field}_#{to}" => translated)
    translated
  end

  def missing_translations
    missing = {}

    TRANSLATABLE_FIELDS.each do |field|
      SUPPORTED_LOCALES.each do |locale|
        if public_send("#{field}_#{locale}").blank?
          missing[field] ||= []
          missing[field] << locale
        end
      end
    end

    missing
  end

  private

  def product_glossary
    {
      "premium" => "premium",
      "pro" => "pro",
      "standard" => "standard",
      brand => brand # Garder le nom de marque
    }
  end
end

# === EXEMPLE 3: Service Object pour traductions en masse ===

class BulkTranslationService
  def initialize(model_class, field_names, options = {})
    @model_class = model_class
    @field_names = Array(field_names)
    @source_locale = options[:source_locale] || "fr"
    @target_locales = options[:target_locales] || %w[en es de]
    @batch_size = options[:batch_size] || 10
    @context = options[:context]
  end

  def translate_all!
    @model_class.find_in_batches(batch_size: @batch_size) do |batch|
      translate_batch!(batch)
      sleep(2) # Rate limiting
    end
  end

  def translate_missing!
    records_with_missing = @model_class.joins(@target_locales.map do |locale|
      "LEFT JOIN #{@model_class.table_name} as #{locale}_table ON #{locale}_table.id = #{@model_class.table_name}.id"
    end.join(" ")).where(
      @target_locales.map do |locale|
        @field_names.map { |field| "#{field}_#{locale} IS NULL OR #{field}_#{locale} = ''" }
      end.flatten.join(" OR ")
    )

    records_with_missing.find_in_batches(batch_size: @batch_size) do |batch|
      translate_batch!(batch)
    end
  end

  private

  def translate_batch!(records)
    records.each do |record|
      @field_names.each do |field|
        source_text = record.public_send("#{field}_#{@source_locale}")
        next if source_text.blank?

        @target_locales.each do |target_locale|
          next unless record.public_send("#{field}_#{target_locale}").blank?

          begin
            translated = MistralTranslator.translate(
              source_text,
              from: @source_locale,
              to: target_locale,
              context: @context
            )

            record.update_column("#{field}_#{target_locale}", translated)
            Rails.logger.info "✅ Translated #{@model_class.name}##{record.id} #{field} to #{target_locale}"
          rescue MistralTranslator::Error => e
            Rails.logger.error "❌ Failed to translate #{@model_class.name}##{record.id}: #{e.message}"
          end
        end
      end
    end
  end
end

# === EXEMPLE 4: Job Sidekiq pour traductions asynchrones ===

class TranslationJob < ApplicationJob
  queue_as :translations
  retry_on MistralTranslator::RateLimitError, wait: :exponentially_longer
  discard_on MistralTranslator::AuthenticationError

  def perform(record, field_names, options = {})
    source_locale = options["source_locale"] || I18n.default_locale.to_s
    target_locales = options["target_locales"] || (I18n.available_locales.map(&:to_s) - [source_locale])
    context = options["context"] || "#{record.class.name.downcase} content"

    Array(field_names).each do |field|
      source_text = record.public_send("#{field}_#{source_locale}")
      next if source_text.blank?

      target_locales.each do |target_locale|
        translated = MistralTranslator.translate(
          source_text,
          from: source_locale,
          to: target_locale,
          context: context
        )

        record.update_column("#{field}_#{target_locale}", translated)
      end
    end

    # Callback optionnel
    record.after_translation_complete if record.respond_to?(:after_translation_complete)
  end
end

# === EXEMPLE 5: Concern réutilisable ===

module Translatable
  extend ActiveSupport::Concern

  included do
    scope :with_missing_translations, lambda { |locale|
      where(translatable_fields.map { |field| "#{field}_#{locale} IS NULL OR #{field}_#{locale} = ''" }.join(" OR "))
    }

    scope :translated_in, lambda { |locale|
      where.not(translatable_fields.map do |field|
        "#{field}_#{locale} IS NULL OR #{field}_#{locale} = ''"
      end.join(" OR "))
    }
  end

  class_methods do
    def translatable_fields(*fields)
      if fields.any?
        @translatable_fields = fields
      else
        @translatable_fields || []
      end
    end

    def supported_locales(*locales)
      if locales.any?
        @supported_locales = locales.map(&:to_s)
      else
        @supported_locales || I18n.available_locales.map(&:to_s)
      end
    end

    def bulk_translate!(source_locale: "fr", target_locales: nil, context: nil)
      target_locales ||= supported_locales - [source_locale.to_s]

      BulkTranslationService.new(
        self,
        translatable_fields,
        source_locale: source_locale,
        target_locales: target_locales,
        context: context || name.downcase
      ).translate_missing!
    end
  end

  def translate_async!(source_locale: I18n.locale, target_locales: nil, context: nil)
    target_locales ||= self.class.supported_locales - [source_locale.to_s]

    TranslationJob.perform_later(
      self,
      self.class.translatable_fields,
      "source_locale" => source_locale.to_s,
      "target_locales" => target_locales,
      "context" => context
    )
  end

  def translation_progress
    total_combinations = self.class.translatable_fields.size * self.class.supported_locales.size
    completed = 0

    self.class.translatable_fields.each do |field|
      self.class.supported_locales.each do |locale|
        completed += 1 unless public_send("#{field}_#{locale}").blank?
      end
    end

    (completed.to_f / total_combinations * 100).round(1)
  end
end

# === UTILISATION ===

puts "=== Exemples Rails Models avec MistralTranslator ==="

# Utilisation du concern
class BlogPost < ApplicationRecord
  include Translatable

  translatable_fields :title, :content, :summary
  supported_locales :fr, :en, :es, :de
end

# Exemples d'utilisation
if defined?(Rails) && Rails.env.development?

  # Test avec un article
  article = Article.create!(
    title_fr: "Les avantages de Ruby on Rails",
    content_fr: "Ruby on Rails est un framework...",
    description_fr: "Guide complet sur Rails"
  )

  puts "Article créé: #{article.title_fr}"

  # Traduction manuelle
  article.translate_to(%i[en es])
  puts "Traduit en: #{article.title_en}, #{article.title_es}"

  # Estimation des coûts
  cost = article.estimate_translation_cost
  puts "Coût estimé: $#{cost[:estimated_cost]} pour #{cost[:target_languages]} langues"

  # Traduction en masse
  puts "\nTraduction en masse des articles..."
  BulkTranslationService.new(
    Article,
    %i[title content],
    source_locale: "fr",
    target_locales: %w[en es],
    context: "blog articles"
  ).translate_missing!

  # Utilisation du concern
  post = BlogPost.create!(
    title_fr: "Nouveau post",
    content_fr: "Contenu du post..."
  )

  puts "Progress: #{post.translation_progress}%"
  post.translate_async!(target_locales: %w[en es])
  puts "Job de traduction lancé"

end

puts "Exemples terminés !"

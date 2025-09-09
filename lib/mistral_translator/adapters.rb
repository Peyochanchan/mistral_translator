# frozen_string_literal: true

module MistralTranslator
  module Adapters
    # Interface de base pour les adaptateurs
    class BaseAdapter
      def initialize(record)
        @record = record
      end

      # Méthodes à implémenter par les adaptateurs spécifiques
      def available_locales
        raise NotImplementedError, "Subclass must implement #available_locales"
      end

      def get_field_value(field, locale)
        raise NotImplementedError, "Subclass must implement #get_field_value"
      end

      def set_field_value(field, locale, value)
        raise NotImplementedError, "Subclass must implement #set_field_value"
      end

      def save_record!
        @record.save!
      end

      # Méthodes utilitaires communes
      def detect_source_locale(field, preferred_locale = nil)
        # Priorité à une locale source fournie
        return preferred_locale.to_sym if preferred_locale && content?(field, preferred_locale)

        # Chercher quelle locale a du contenu pour ce champ
        available_locales.each do |locale|
          return locale if content?(field, locale)
        end

        # Fallback sur la première locale disponible
        available_locales.first
      end

      def content?(field, locale)
        value = get_field_value(field, locale)
        return false if value.nil?

        # Gestion des rich text
        if defined?(ActionText::RichText) && value.is_a?(ActionText::RichText)
          !value.to_plain_text.to_s.strip.empty?
        else
          !value.to_s.strip.empty?
        end
      end

      def get_translatable_content(field, locale)
        value = get_field_value(field, locale)
        return nil if value.nil?

        # Gestion des rich text - préserver le HTML
        if defined?(ActionText::RichText) && value.is_a?(ActionText::RichText)
          value.body.to_s
        else
          value.to_s
        end
      end
    end

    # Adaptateur pour Mobility
    class MobilityAdapter < BaseAdapter
      def available_locales
        I18n.available_locales
      end

      def get_field_value(field, locale)
        @record.public_send("#{field}_#{locale}")
      rescue NoMethodError
        nil
      end

      def set_field_value(field, locale, value)
        @record.public_send("#{field}_#{locale}=", value)
      end
    end

    # Adaptateur pour les attributs I18n standards avec suffixes
    class I18nAttributesAdapter < BaseAdapter
      def available_locales
        I18n.available_locales
      end

      def get_field_value(field, locale)
        @record.public_send("#{field}_#{locale}")
      rescue NoMethodError
        nil
      end

      def set_field_value(field, locale, value)
        @record.public_send("#{field}_#{locale}=", value)
      end
    end

    # Adaptateur pour Globalize
    class GlobalizeAdapter < BaseAdapter
      def available_locales
        @record.class.translated_locales || I18n.available_locales
      end

      def get_field_value(field, locale)
        I18n.with_locale(locale) do
          @record.public_send(field)
        end
      rescue NoMethodError
        nil
      end

      def set_field_value(field, locale, value)
        I18n.with_locale(locale) do
          @record.public_send("#{field}=", value)
        end
      end
    end

    # Adaptateur pour des méthodes custom
    class CustomAdapter < BaseAdapter
      def initialize(record, options = {})
        super(record)
        @get_method = options[:get_method] || :get_translation
        @set_method = options[:set_method] || :set_translation
        @locales_method = options[:locales_method] || :available_locales
      end

      def available_locales
        if @record.respond_to?(@locales_method)
          @record.public_send(@locales_method)
        else
          I18n.available_locales
        end
      end

      def get_field_value(field, locale)
        @record.public_send(@get_method, field, locale)
      rescue NoMethodError
        nil
      end

      def set_field_value(field, locale, value)
        @record.public_send(@set_method, field, locale, value)
      end
    end

    # Factory pour détecter automatiquement l'adaptateur approprié
    class AdapterFactory
      def self.build_for(record)
        # Détecter Mobility
        return MobilityAdapter.new(record) if defined?(Mobility) && record.class.respond_to?(:mobility_attributes)

        # Détecter Globalize
        if defined?(Globalize) && record.class.respond_to?(:translated_attribute_names)
          return GlobalizeAdapter.new(record)
        end

        # Par défaut, essayer l'adaptateur I18n avec suffixes
        I18nAttributesAdapter.new(record)
      end
    end
  end

  # Service de traduction utilisant les adaptateurs
  module Adapters
    class RecordTranslationService
      def initialize(record, translatable_fields, adapter: nil, source_locale: nil)
        @record = record
        @translatable_fields = Array(translatable_fields)
        @adapter = adapter || Adapters::AdapterFactory.build_for(record)
        @source_locale = source_locale
      end

      def translate_to_all_locales
        return false if @translatable_fields.empty?

        ActiveRecord::Base.transaction do
          @translatable_fields.each do |field|
            translate_field(field)
          end
          @adapter.save_record!
        end

        true
      rescue StandardError => e
        Rails.logger.error "Translation failed: #{e.message}" if defined?(Rails)
        false
      end

      private

      def translate_field(field)
        source_locale = @adapter.detect_source_locale(field, @source_locale)
        source_content = @adapter.get_translatable_content(field, source_locale)

        return if source_content.nil? || source_content.strip.empty?

        target_locales = @adapter.available_locales - [source_locale]

        target_locales.each do |target_locale|
          translate_to_locale(field, source_content, source_locale, target_locale)
          sleep(2) # Rate limiting basique
        end
      end

      def translate_to_locale(field, content, source_locale, target_locale)
        translated_content = MistralTranslator.translate(
          content,
          from: source_locale.to_s,
          to: target_locale.to_s
        )

        if translated_content && !translated_content.strip.empty?
          @adapter.set_field_value(field, target_locale,
                                   translated_content)
        end
      rescue MistralTranslator::RateLimitError => e
        Rails.logger.warn "Rate limit: #{e.message}" if defined?(Rails)
        sleep(2)
        retry
      rescue StandardError => e
        if defined?(Rails)
          Rails.logger.error "Translation error for #{field} #{source_locale}->#{target_locale}: #{e.message}"
        end
      end
    end
  end

  # Méthodes de convenance pour utilisation directe
  module RecordTranslation
    def self.translate_record(record, fields, adapter: nil, source_locale: nil)
      service = Adapters::RecordTranslationService.new(record, fields, adapter: adapter, source_locale: source_locale)
      service.translate_to_all_locales
    end

    # Pour Mobility (exemple d'usage)
    def self.translate_mobility_record(record, fields, source_locale: nil)
      adapter = Adapters::MobilityAdapter.new(record)
      translate_record(record, fields, adapter: adapter, source_locale: source_locale)
    end

    # Pour Globalize (exemple d'usage)
    def self.translate_globalize_record(record, fields, source_locale: nil)
      adapter = Adapters::GlobalizeAdapter.new(record)
      translate_record(record, fields, adapter: adapter, source_locale: source_locale)
    end

    # Pour des méthodes custom
    def self.translate_custom_record(record, fields, get_method:, set_method:, **options)
      adapter = Adapters::CustomAdapter.new(record, {
                                              get_method: get_method,
                                              set_method: set_method,
                                              locales_method: options[:locales_method]
                                            })
      translate_record(record, fields, adapter: adapter, source_locale: options[:source_locale])
    end
  end
end

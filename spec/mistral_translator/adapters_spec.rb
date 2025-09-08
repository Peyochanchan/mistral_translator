# frozen_string_literal: true

RSpec.describe MistralTranslator::Adapters do
  # Mock record pour les tests
  let(:mock_record) do
    record = double("ActiveRecord")
    allow(record).to receive(:save!).and_return(true)
    record
  end

  describe "BaseAdapter" do
    let(:adapter) { MistralTranslator::Adapters::BaseAdapter.new(mock_record) }

    describe "#initialize" do
      it "stores the record" do
        expect(adapter.instance_variable_get(:@record)).to eq(mock_record)
      end
    end

    describe "interface methods" do
      it "raises NotImplementedError for available_locales" do
        expect { adapter.available_locales }.to raise_error(NotImplementedError)
      end

      it "raises NotImplementedError for get_field_value" do
        expect { adapter.get_field_value("name", "fr") }.to raise_error(NotImplementedError)
      end

      it "raises NotImplementedError for set_field_value" do
        expect { adapter.set_field_value("name", "fr", "value") }.to raise_error(NotImplementedError)
      end
    end

    describe "#save_record!" do
      it "delegates to record.save!" do
        expect(mock_record).to receive(:save!)
        adapter.save_record!
      end
    end

    describe "#detect_source_locale" do
      before do
        allow(adapter).to receive(:available_locales).and_return(%i[fr en es])
        allow(adapter).to receive(:has_content?).with("name", :fr).and_return(true)
        allow(adapter).to receive(:has_content?).with("name", :en).and_return(false)
        allow(adapter).to receive(:has_content?).with("name", :es).and_return(false)
      end

      it "returns preferred locale when it has content" do
        allow(adapter).to receive(:has_content?).with("name", :en).and_return(true)

        result = adapter.detect_source_locale("name", :en)
        expect(result).to eq(:en)
      end

      it "finds first locale with content when no preferred" do
        result = adapter.detect_source_locale("name")
        expect(result).to eq(:fr)
      end

      it "returns first available locale as fallback" do
        allow(adapter).to receive(:has_content?).and_return(false)

        result = adapter.detect_source_locale("name")
        expect(result).to eq(:fr)
      end
    end

    describe "#has_content?" do
      it "returns false for nil value" do
        allow(adapter).to receive(:get_field_value).and_return(nil)
        expect(adapter.has_content?("name", :fr)).to be false
      end

      it "returns true for string content" do
        allow(adapter).to receive(:get_field_value).and_return("content")
        expect(adapter.has_content?("name", :fr)).to be true
      end

      it "returns false for empty string" do
        allow(adapter).to receive(:get_field_value).and_return("")
        expect(adapter.has_content?("name", :fr)).to be false
      end

      context "with ActionText" do
        let(:mock_rich_text) do
          double("ActionText::RichText", to_plain_text: "plain content")
        end

        before do
          stub_const("ActionText::RichText", Class.new)
          allow(mock_rich_text).to receive(:is_a?).with(ActionText::RichText).and_return(true)
        end

        it "returns true for rich text with content" do
          allow(adapter).to receive(:get_field_value).and_return(mock_rich_text)
          expect(adapter.has_content?("description", :fr)).to be true
        end

        it "returns false for rich text without content" do
          allow(mock_rich_text).to receive(:to_plain_text).and_return("")
          allow(adapter).to receive(:get_field_value).and_return(mock_rich_text)
          expect(adapter.has_content?("description", :fr)).to be false
        end
      end
    end

    describe "#get_translatable_content" do
      it "returns nil for nil value" do
        allow(adapter).to receive(:get_field_value).and_return(nil)
        expect(adapter.get_translatable_content("name", :fr)).to be_nil
      end

      it "returns string content as is" do
        allow(adapter).to receive(:get_field_value).and_return("content")
        expect(adapter.get_translatable_content("name", :fr)).to eq("content")
      end

      context "with ActionText" do
        let(:mock_rich_text) do
          body = double("body", to_s: "<p>HTML content</p>")
          double("ActionText::RichText", body: body)
        end

        before do
          stub_const("ActionText::RichText", Class.new)
          allow(mock_rich_text).to receive(:is_a?).with(ActionText::RichText).and_return(true)
        end

        it "returns HTML body for rich text" do
          allow(adapter).to receive(:get_field_value).and_return(mock_rich_text)
          expect(adapter.get_translatable_content("description", :fr)).to eq("<p>HTML content</p>")
        end
      end
    end
  end

  describe "MobilityAdapter" do
    let(:adapter) { MistralTranslator::Adapters::MobilityAdapter.new(mock_record) }

    before do
      # Mock I18n.available_locales
      allow(I18n).to receive(:available_locales).and_return(%i[fr en es])
    end

    describe "#available_locales" do
      it "returns I18n.available_locales" do
        expect(adapter.available_locales).to eq(%i[fr en es])
      end
    end

    describe "#get_field_value" do
      it "calls record method with locale suffix" do
        expect(mock_record).to receive(:name_fr).and_return("Nom français")

        result = adapter.get_field_value("name", :fr)
        expect(result).to eq("Nom français")
      end

      it "returns nil for missing method" do
        allow(mock_record).to receive(:name_xx).and_raise(NoMethodError)

        result = adapter.get_field_value("name", :xx)
        expect(result).to be_nil
      end
    end

    describe "#set_field_value" do
      it "calls record setter method with locale suffix" do
        expect(mock_record).to receive(:name_fr=).with("Nouveau nom")

        adapter.set_field_value("name", :fr, "Nouveau nom")
      end
    end
  end

  describe "I18nAttributesAdapter" do
    let(:adapter) { MistralTranslator::Adapters::I18nAttributesAdapter.new(mock_record) }

    before do
      allow(I18n).to receive(:available_locales).and_return(%i[fr en es])
    end

    describe "#available_locales" do
      it "returns I18n.available_locales" do
        expect(adapter.available_locales).to eq(%i[fr en es])
      end
    end

    describe "#get_field_value" do
      it "calls record method with locale suffix" do
        expect(mock_record).to receive(:title_en).and_return("English title")

        result = adapter.get_field_value("title", :en)
        expect(result).to eq("English title")
      end

      it "returns nil for missing method" do
        allow(mock_record).to receive(:title_invalid).and_raise(NoMethodError)

        result = adapter.get_field_value("title", :invalid)
        expect(result).to be_nil
      end
    end

    describe "#set_field_value" do
      it "calls record setter method with locale suffix" do
        expect(mock_record).to receive(:title_en=).with("New title")

        adapter.set_field_value("title", :en, "New title")
      end
    end
  end

  describe "GlobalizeAdapter" do
    let(:adapter) { MistralTranslator::Adapters::GlobalizeAdapter.new(mock_record) }
    let(:mock_class) { double("RecordClass") }

    before do
      allow(mock_record).to receive(:class).and_return(mock_class)
      allow(mock_class).to receive(:translated_locales).and_return(%i[fr en])
    end

    describe "#available_locales" do
      it "returns class translated_locales when available" do
        expect(adapter.available_locales).to eq(%i[fr en])
      end

      it "falls back to I18n.available_locales" do
        allow(mock_class).to receive(:translated_locales).and_return(nil)
        allow(I18n).to receive(:available_locales).and_return(%i[fr en es])

        expect(adapter.available_locales).to eq(%i[fr en es])
      end
    end

    describe "#get_field_value" do
      it "uses I18n.with_locale to get value" do
        expect(I18n).to receive(:with_locale).with(:fr).and_yield
        expect(mock_record).to receive(:name).and_return("Nom français")

        result = adapter.get_field_value("name", :fr)
        expect(result).to eq("Nom français")
      end

      it "returns nil for missing method" do
        expect(I18n).to receive(:with_locale).with(:fr).and_yield
        allow(mock_record).to receive(:invalid_field).and_raise(NoMethodError)

        result = adapter.get_field_value("invalid_field", :fr)
        expect(result).to be_nil
      end
    end

    describe "#set_field_value" do
      it "uses I18n.with_locale to set value" do
        expect(I18n).to receive(:with_locale).with(:en).and_yield
        expect(mock_record).to receive(:name=).with("English name")

        adapter.set_field_value("name", :en, "English name")
      end
    end
  end

  describe "CustomAdapter" do
    let(:options) do
      {
        get_method: :get_translation,
        set_method: :set_translation,
        locales_method: :available_locales
      }
    end
    let(:adapter) { MistralTranslator::Adapters::CustomAdapter.new(mock_record, options) }

    describe "#initialize" do
      it "uses provided options" do
        expect(adapter.instance_variable_get(:@get_method)).to eq(:get_translation)
        expect(adapter.instance_variable_get(:@set_method)).to eq(:set_translation)
        expect(adapter.instance_variable_get(:@locales_method)).to eq(:available_locales)
      end

      it "uses default methods when not provided" do
        default_adapter = MistralTranslator::Adapters::CustomAdapter.new(mock_record)
        expect(default_adapter.instance_variable_get(:@get_method)).to eq(:get_translation)
        expect(default_adapter.instance_variable_get(:@set_method)).to eq(:set_translation)
        expect(default_adapter.instance_variable_get(:@locales_method)).to eq(:available_locales)
      end
    end

    describe "#available_locales" do
      it "calls record's locales method when available" do
        expect(mock_record).to receive(:available_locales).and_return(%i[fr en])
        expect(adapter.available_locales).to eq(%i[fr en])
      end

      it "falls back to I18n.available_locales" do
        allow(mock_record).to receive(:respond_to?).with(:available_locales).and_return(false)
        allow(I18n).to receive(:available_locales).and_return(%i[fr en es])

        expect(adapter.available_locales).to eq(%i[fr en es])
      end
    end

    describe "#get_field_value" do
      it "calls record's get method" do
        expect(mock_record).to receive(:get_translation).with("name", :fr).and_return("Nom")

        result = adapter.get_field_value("name", :fr)
        expect(result).to eq("Nom")
      end

      it "returns nil for missing method" do
        allow(mock_record).to receive(:get_translation).and_raise(NoMethodError)

        result = adapter.get_field_value("name", :fr)
        expect(result).to be_nil
      end
    end

    describe "#set_field_value" do
      it "calls record's set method" do
        expect(mock_record).to receive(:set_translation).with("name", :fr, "Nouveau nom")

        adapter.set_field_value("name", :fr, "Nouveau nom")
      end
    end
  end

  describe "AdapterFactory" do
    describe ".build_for" do
      context "with Mobility" do
        let(:mobility_record) do
          record = double("MobilityRecord")
          record_class = double("MobilityRecordClass")
          allow(record).to receive(:class).and_return(record_class)
          allow(record_class).to receive(:respond_to?).with(:mobility_attributes).and_return(true)
          record
        end

        before do
          stub_const("Mobility", Module.new)
        end

        it "returns MobilityAdapter" do
          adapter = MistralTranslator::Adapters::AdapterFactory.build_for(mobility_record)
          expect(adapter).to be_a(MistralTranslator::Adapters::MobilityAdapter)
        end
      end

      context "with Globalize" do
        let(:globalize_record) do
          record = double("GlobalizeRecord")
          record_class = double("GlobalizeRecordClass")
          allow(record).to receive(:class).and_return(record_class)
          allow(record_class).to receive(:respond_to?).with(:mobility_attributes).and_return(false)
          allow(record_class).to receive(:respond_to?).with(:translated_attribute_names).and_return(true)
          record
        end

        before do
          stub_const("Globalize", Module.new)
        end

        it "returns GlobalizeAdapter" do
          adapter = MistralTranslator::Adapters::AdapterFactory.build_for(globalize_record)
          expect(adapter).to be_a(MistralTranslator::Adapters::GlobalizeAdapter)
        end
      end

      context "with default record" do
        let(:default_record) do
          record = double("DefaultRecord")
          record_class = double("DefaultRecordClass")
          allow(record).to receive(:class).and_return(record_class)
          allow(record_class).to receive(:respond_to?).and_return(false)
          record
        end

        it "returns I18nAttributesAdapter" do
          adapter = MistralTranslator::Adapters::AdapterFactory.build_for(default_record)
          expect(adapter).to be_a(MistralTranslator::Adapters::I18nAttributesAdapter)
        end
      end
    end
  end

  describe "RecordTranslationService" do
    let(:translatable_fields) { %w[name description] }
    let(:service) { MistralTranslator::Adapters::RecordTranslationService.new(mock_record, translatable_fields) }
    let(:mock_adapter) { instance_double(MistralTranslator::Adapters::BaseAdapter) }

    before do
      allow(MistralTranslator::Adapters::AdapterFactory).to receive(:build_for).and_return(mock_adapter)
      allow(mock_adapter).to receive(:save_record!)

      # Mock MistralTranslator.translate
      allow(MistralTranslator).to receive(:translate).and_return("Translated content")
    end

    describe "#initialize" do
      it "stores fields and creates adapter" do
        expect(service.instance_variable_get(:@translatable_fields)).to eq(%w[name description])
        expect(service.instance_variable_get(:@adapter)).to eq(mock_adapter)
      end

      it "accepts custom adapter" do
        custom_adapter = double("CustomAdapter")
        custom_service = MistralTranslator::Adapters::RecordTranslationService.new(
          mock_record,
          translatable_fields,
          adapter: custom_adapter
        )

        expect(custom_service.instance_variable_get(:@adapter)).to eq(custom_adapter)
      end
    end

    describe "#translate_to_all_locales" do
      before do
        allow(mock_adapter).to receive(:detect_source_locale).and_return(:fr)
        allow(mock_adapter).to receive(:get_translatable_content).and_return("Content français")
        allow(mock_adapter).to receive(:available_locales).and_return(%i[fr en es])
        allow(mock_adapter).to receive(:set_field_value)
      end

      it "returns false for empty fields" do
        empty_service = MistralTranslator::Adapters::RecordTranslationService.new(mock_record, [])
        expect(empty_service.translate_to_all_locales).to be false
      end

      it "translates all fields to all locales" do
        # Doit détecter la source pour chaque champ
        expect(mock_adapter).to receive(:detect_source_locale).with("name", nil).and_return(:fr)
        expect(mock_adapter).to receive(:detect_source_locale).with("description", nil).and_return(:fr)

        # Doit récupérer le contenu source
        expect(mock_adapter).to receive(:get_translatable_content).with("name", :fr).and_return("Nom")
        expect(mock_adapter).to receive(:get_translatable_content).with("description", :fr).and_return("Description")

        # Doit traduire vers les langues cibles (en, es)
        expect(MistralTranslator).to receive(:translate).with("Nom", from: "fr", to: "en").and_return("Name")
        expect(MistralTranslator).to receive(:translate).with("Nom", from: "fr", to: "es").and_return("Nombre")
        expect(MistralTranslator).to receive(:translate).with("Description", from: "fr",
                                                                             to: "en").and_return("Description EN")
        expect(MistralTranslator).to receive(:translate).with("Description", from: "fr",
                                                                             to: "es").and_return("Description ES")

        # Doit définir les valeurs traduites
        expect(mock_adapter).to receive(:set_field_value).with("name", :en, "Name")
        expect(mock_adapter).to receive(:set_field_value).with("name", :es, "Nombre")
        expect(mock_adapter).to receive(:set_field_value).with("description", :en, "Description EN")
        expect(mock_adapter).to receive(:set_field_value).with("description", :es, "Description ES")

        result = service.translate_to_all_locales
        expect(result).to be true
      end

      it "handles empty content gracefully" do
        allow(mock_adapter).to receive(:get_translatable_content).and_return("")

        # Ne doit pas essayer de traduire du contenu vide
        expect(MistralTranslator).not_to receive(:translate)

        result = service.translate_to_all_locales
        expect(result).to be true
      end

      it "handles rate limit errors" do
        # Configurer pour qu'un seul champ ait du contenu
        allow(mock_adapter).to receive(:get_translatable_content).with("name", :fr).and_return("Nom")
        allow(mock_adapter).to receive(:get_translatable_content).with("description", :fr).and_return("")

        # Premier appel échoue avec rate limit, deuxième réussit
        call_count = 0
        allow(MistralTranslator).to receive(:translate) do |*args|
          call_count += 1
          raise MistralTranslator::RateLimitError, "API rate limit exceeded" if call_count == 1

          "Name"
        end

        expect(service).to receive(:sleep).with(2).at_least(:once)

        result = service.translate_to_all_locales
        expect(result).to be true
      end

      it "returns false on unexpected errors" do
        allow(mock_adapter).to receive(:save_record!).and_raise(StandardError, "Database error")

        result = service.translate_to_all_locales
        expect(result).to be false
      end
    end
  end

  describe "RecordTranslation module" do
    describe ".translate_record" do
      it "creates service and calls translate_to_all_locales" do
        service_double = instance_double(MistralTranslator::Adapters::RecordTranslationService)
        expect(MistralTranslator::Adapters::RecordTranslationService).to receive(:new)
          .with(mock_record, ["name"], adapter: nil, source_locale: nil)
          .and_return(service_double)
        expect(service_double).to receive(:translate_to_all_locales).and_return(true)

        result = MistralTranslator::RecordTranslation.translate_record(mock_record, ["name"])
        expect(result).to be true
      end
    end

    describe ".translate_mobility_record" do
      it "uses MobilityAdapter" do
        adapter_double = instance_double(MistralTranslator::Adapters::MobilityAdapter)
        expect(MistralTranslator::Adapters::MobilityAdapter).to receive(:new).with(mock_record).and_return(adapter_double)
        expect(MistralTranslator::RecordTranslation).to receive(:translate_record)
          .with(mock_record, ["name"], adapter: adapter_double, source_locale: :fr)

        MistralTranslator::RecordTranslation.translate_mobility_record(mock_record, ["name"], source_locale: :fr)
      end
    end

    describe ".translate_globalize_record" do
      it "uses GlobalizeAdapter" do
        adapter_double = instance_double(MistralTranslator::Adapters::GlobalizeAdapter)
        expect(MistralTranslator::Adapters::GlobalizeAdapter).to receive(:new).with(mock_record).and_return(adapter_double)
        expect(MistralTranslator::RecordTranslation).to receive(:translate_record)
          .with(mock_record, ["name"], adapter: adapter_double, source_locale: :en)

        MistralTranslator::RecordTranslation.translate_globalize_record(mock_record, ["name"], source_locale: :en)
      end
    end

    describe ".translate_custom_record" do
      it "uses CustomAdapter with provided methods" do
        adapter_double = instance_double(MistralTranslator::Adapters::CustomAdapter)
        expect(MistralTranslator::Adapters::CustomAdapter).to receive(:new)
          .with(mock_record, { get_method: :get_trans, set_method: :set_trans, locales_method: nil })
          .and_return(adapter_double)
        expect(MistralTranslator::RecordTranslation).to receive(:translate_record)
          .with(mock_record, ["name"], adapter: adapter_double, source_locale: nil)

        MistralTranslator::RecordTranslation.translate_custom_record(
          mock_record,
          ["name"],
          get_method: :get_trans,
          set_method: :set_trans
        )
      end
    end
  end
end

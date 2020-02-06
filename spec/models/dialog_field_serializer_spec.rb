RSpec.describe DialogFieldSerializer do
  let(:resource_action_serializer) { double("ResourceActionSerializer") }
  let(:dialog_field_serializer) { described_class.new(resource_action_serializer) }

  describe "#serialize" do
    let(:resource_action) { ResourceAction.new }
    let(:dialog_field_responders) { [] }
    let(:options) { {"options" => true} }
    let(:expected_serialized_values) do
      {
        "name"                    => "name",
        "description"             => "description",
        "type"                    => type,
        "data_type"               => "data_type",
        "notes"                   => "notes",
        "notes_display"           => "notes display",
        "display"                 => "display",
        "display_method"          => "display method",
        "display_method_options"  => {"display method options" => true},
        "dynamic"                 => dynamic,
        "required"                => false,
        "required_method"         => "required method",
        "required_method_options" => {"required method options" => true},
        "show_refresh_button"     => false,
        "default_value"           => "default value",
        "values_method"           => "values method",
        "values_method_options"   => {"values method options" => true},
        "options"                 => options,
        "label"                   => "label",
        "load_values_on_init"     => false,
        "position"                => 1,
        "read_only"               => false,
        "auto_refresh"            => false,
        "trigger_auto_refresh"    => false,
        "visible"                 => true,
        "validator_type"          => "validator_type",
        "validator_rule"          => "validator_rule",
        "reconfigurable"          => nil
      }
    end

    before do
      allow(resource_action_serializer)
        .to receive(:serialize).with(resource_action).and_return("serialized resource action")
    end

    context "when the dialog_field is dynamic" do
      let(:dynamic) { true }

      context "when the field is a sorted item type" do
        let(:type) { "DialogFieldDropDownList" }
        let(:dialog_field) { DialogFieldDropDownList.new(expected_serialized_values.merge(:resource_action => resource_action, :dialog_field_responders => dialog_field_responders)) }

        before do
          allow(dialog_field).to receive(:extract_dynamic_values).and_return("dynamic values")
        end

        context 'when wanting the excluded set of attributes' do
          let(:all_attributes) { false }

          it 'serializes the dialog_field with the correct attributes' do
            expect(dialog_field_serializer.serialize(dialog_field, all_attributes))
            .to eq(expected_serialized_values.merge(
                     "resource_action"         => "serialized resource action",
                     "values"                  => "dynamic values",
                     "dialog_field_responders" => dialog_field_responders
            ))
          end
        end

        context 'when wanting all attributes' do
          let(:all_attributes) { true }

          it 'serializes the dialog_field with all attributes' do
            expect(dialog_field_serializer.serialize(dialog_field, all_attributes))
            .to include(expected_serialized_values.merge(
                          'id'                      => dialog_field.id,
                          'resource_action'         => 'serialized resource action',
                          'dialog_field_responders' => [],
                          'values'                  => 'dynamic values'
            ))
          end
        end

        let(:all_attributes) { true }
        let(:dialog_field_with_values) { DialogFieldDropDownList.new(expected_serialized_values.merge(:resource_action => resource_action, :dialog_field_responders => dialog_field_responders, :values => "drew")) }

        it 'does not call values' do
          expect(dialog_field_serializer.serialize(dialog_field_with_values, all_attributes))
            .to include(expected_serialized_values.merge(
                          'id'                      => dialog_field.id,
                          'resource_action'         => 'serialized resource action',
                          'dialog_field_responders' => [],
                          'values'                  => nil
            ))
        end
      end

      context "when the field is not a sorted item type" do
        let(:dialog_field) { DialogFieldTextBox.new(expected_serialized_values.merge(:resource_action => resource_action, :dialog_field_responders => dialog_field_responders)) }
        let(:type) { "DialogFieldTextBox" }

        before do
          allow(dialog_field).to receive(:extract_dynamic_values).and_return("automate default value")
        end

        context 'when wanting the excluded set of attributes' do
          let(:all_attributes) { false }

          it 'serializes the dialog_field with the correct attributes' do
            expect(dialog_field_serializer.serialize(dialog_field, all_attributes))
              .to eq(expected_serialized_values.merge(
                       "resource_action"         => "serialized resource action",
                       "dialog_field_responders" => dialog_field_responders,
                       "default_value"           => "automate default value",
              ))
          end
        end

        context 'when wanting all attributes' do
          let(:all_attributes) { true }

          it 'serializes the dialog_field with all attributes' do
            expect(dialog_field_serializer.serialize(dialog_field, all_attributes))
              .to include(expected_serialized_values.merge(
                            'id'                      => dialog_field.id,
                            'resource_action'         => 'serialized resource action',
                            'dialog_field_responders' => [],
                            "default_value"           => "automate default value"
              ))
          end
        end
      end
    end

    context "when the dialog_field is not dynamic" do
      let(:dynamic) { false }
      let(:dialog_field) { DialogFieldTextBox.new(expected_serialized_values.merge(:resource_action => resource_action, :dialog_field_responders => dialog_field_responders)) }
      let(:type) { "DialogFieldTextBox" }

      context 'when wanting the excluded set of attributes' do
        let(:all_attributes) { false }

        it "serializes the dialog_field with the correct values" do
          expect(dialog_field_serializer.serialize(dialog_field, all_attributes))
            .to eq(expected_serialized_values.merge(
                     "resource_action"         => "serialized resource action",
                     "dialog_field_responders" => dialog_field_responders,
                     "values"                  => nil
            ))
        end
      end

      context 'when wanting all attributes' do
        let(:all_attributes) { true }

        it 'serializes the dialog_field with all attributes' do
          expect(dialog_field_serializer.serialize(dialog_field, all_attributes))
            .to include(expected_serialized_values.merge(
                          'id'                      => dialog_field.id,
                          'resource_action'         => 'serialized resource action',
                          'dialog_field_responders' => [],
            ))
        end

        context 'with associations' do
          let(:dialog_field_responders) { [FactoryBot.build(:dialog_field_text_box)] }

          it 'serializes the dialog_field with all attributes and non_empty associations' do
            expect(dialog_field_serializer.serialize(dialog_field, dialog_field_responders))
              .to include(expected_serialized_values.merge(
                            "resource_action"         => "serialized resource action",
                            "dialog_field_responders" => ["Dialog Field"]
              ))
          end
        end
      end

      context "when the dialog field is a drop down list" do
        let(:dynamic) { false }
        let(:dialog_field) { DialogFieldDropDownList.new(expected_serialized_values.merge(:resource_action => resource_action, :dialog_field_responders => dialog_field_responders, :values => [%w[one one], %w[two two]])) }
        let(:type) { "DialogFieldDropDownList" }

        context 'when wanting the excluded set of attributes' do
          let(:all_attributes) { false }

          it "serializes the dialog_field with the correct values" do
            expect(dialog_field_serializer.serialize(dialog_field, all_attributes))
              .to eq(expected_serialized_values.merge(
                       "resource_action"         => "serialized resource action",
                       "dialog_field_responders" => dialog_field_responders,
                       "values"                  => [[nil, "<None>"], %w[one one], %w[two two]]
              ))
          end
        end

        context 'when wanting all attributes' do
          let(:all_attributes) { true }

          it 'serializes the dialog_field with all attributes' do
            expect(dialog_field_serializer.serialize(dialog_field, all_attributes))
              .to include(expected_serialized_values.merge(
                            'id'                      => dialog_field.id,
                            'resource_action'         => 'serialized resource action',
                            'dialog_field_responders' => []
              ))
          end
        end
      end
    end

    context "when the dialog_field is a tag control type" do
      let(:dialog_field) do
        DialogFieldTagControl.new(expected_serialized_values.merge(
          :resource_action         => resource_action,
          :dialog_field_responders => dialog_field_responders
        ))
      end

      let(:type) { "DialogFieldTagControl" }
      let(:options) { {:category_id => "123", :force_single_value => false} }
      let(:dynamic) { false }
      let(:category) do
        double("Category", :name => "best category ever", :description => "best category ever", :single_value => true)
      end

      before do
        allow(Category).to receive(:find_by).with(:id => "123").and_return(category)
        allow(dialog_field).to receive(:values).and_return("values")
      end

      it "serializes the category name, description and default value" do
        default_values = "[\"one\", \"two\"]"
        dialog_field.update(:default_value => default_values)

        expect(dialog_field_serializer.serialize(dialog_field))
          .to eq(expected_serialized_values.merge(
                   "resource_action"         => "serialized resource action",
                   "dialog_field_responders" => dialog_field_responders,
                   "options"                 => {
                     :category_id          => "123",
                     :category_name        => "best category ever",
                     :category_description => "best category ever",
                     :force_single_value   => true
                   },
                   "default_value"           => "[\"one\", \"two\"]",
                   "values"                  => "values"
          ))
      end
    end
  end
end

describe DialogFieldSerializer do
  let(:resource_action_serializer) { double("ResourceActionSerializer") }
  let(:dialog_field_serializer) { described_class.new(resource_action_serializer) }

  describe "#serialize" do
    let(:dialog_field) { DialogFieldTextBox.new(expected_serialized_values.merge(:resource_action => resource_action)) }
    let(:type) { "DialogFieldTextBox" }
    let(:resource_action) { ResourceAction.new }
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
        "values"                  => "values",
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

      before do
        allow(dialog_field).to receive(:trigger_automate_value_updates).and_return("dynamic values")
      end

      it "serializes the dialog_field with the correct values" do
        expect(dialog_field_serializer.serialize(dialog_field))
          .to eq(expected_serialized_values.merge(
                   "resource_action" => "serialized resource action",
                   "values"          => "dynamic values"
          ))
      end

      it 'returns all attributes of a dialog field' do
        expect(dialog_field_serializer.serialize(dialog_field, true))
          .to include(expected_serialized_values.merge(
                        'id'              => dialog_field.id,
                        'resource_action' => 'serialized resource action',
                        'values'          => 'dynamic values'
          ))
      end
    end

    context "when the dialog_field is not dynamic" do
      let(:dynamic) { false }

      it "serializes the dialog_field" do
        expect(dialog_field_serializer.serialize(dialog_field))
          .to eq(expected_serialized_values.merge(
                   "resource_action" => "serialized resource action"
          ))
      end

      it 'returns all attributes of a dialog field' do
        expect(dialog_field_serializer.serialize(dialog_field, true))
          .to include(expected_serialized_values.merge(
                        'id'              => dialog_field.id,
                        'resource_action' => 'serialized resource action',
          ))
      end
    end

    context "when the dialog_field is a tag control type" do
      let(:dialog_field) do
        DialogFieldTagControl.new(expected_serialized_values.merge(:resource_action => resource_action))
      end

      let(:type) { "DialogFieldTagControl" }
      let(:options) { {:category_id => "123"} }
      let(:dynamic) { false }
      let(:category) { double("Category", :name => "best category ever", :description => "best category ever") }

      before do
        allow(Category).to receive(:find_by).with(:id => "123").and_return(category)
        allow(dialog_field).to receive(:values).and_return("values")
      end

      it "serializes the category name and description" do
        expect(dialog_field_serializer.serialize(dialog_field))
          .to eq(expected_serialized_values.merge(
                   "resource_action" => "serialized resource action",
                   "options"         => {
                     :category_id          => "123",
                     :category_name        => "best category ever",
                     :category_description => "best category ever"
                   }
          ))
      end
    end
  end
end

require "spec_helper"

describe DialogFieldSerializer do
  let(:resource_action_serializer) { auto_loaded_instance_double("ResourceActionSerializer") }
  let(:dialog_field_serializer) { described_class.new(resource_action_serializer) }

  describe "#serialize" do
    let(:dialog_field) { DialogFieldTextBox.new(expected_serialized_values.merge(:resource_action => resource_action)) }
    let(:resource_action) { ResourceAction.new }
    let(:expected_serialized_values) do
      {
        "name"                    => "name",
        "description"             => "description",
        "type"                    => "DialogFieldTextBox",
        "data_type"               => "data_type",
        "notes"                   => "notes",
        "notes_display"           => "notes display",
        "display"                 => "display",
        "display_method"          => "display method",
        "display_method_options"  => {"display method options" => true},
        "dynamic"                 => false,
        "required"                => false,
        "required_method"         => "required method",
        "required_method_options" => {"required method options" => true},
        "show_refresh_button"     => false,
        "default_value"           => "default value",
        "values"                  => "values",
        "values_method"           => "values method",
        "values_method_options"   => {"values method options" => true},
        "options"                 => {"options" => true},
        "label"                   => "label",
        "load_values_on_init"     => false,
        "position"                => 1,
        "read_only"               => false,
        "validator_type"          => "validator_type",
        "validator_rule"          => "validator_rule",
        "reconfigurable"          => nil
      }
    end

    before do
      resource_action_serializer.stub(:serialize).with(resource_action).and_return("serialized resource action")
    end

    it "serializes the dialog_field" do
      dialog_field_serializer.serialize(dialog_field).should == expected_serialized_values.merge(
        "resource_action" => "serialized resource action"
      )
    end
  end
end

require "spec_helper"

describe DialogFieldSerializer do
  let(:dialog_field_serializer) { described_class.new }
  let(:dialog_field) { DialogField.new(expected_serialized_values) }

  let(:expected_serialized_values) do
    {
      "name"                    => "name",
      "description"             => "description",
      "type"                    => nil,
      "data_type"               => "data_type",
      "notes"                   => "notes",
      "notes_display"           => "notes display",
      "display"                 => "display",
      "display_method"          => "display method",
      "display_method_options"  => "display method options",
      "required"                => false,
      "required_method"         => "required method",
      "required_method_options" => "required method options",
      "default_value"           => "default value",
      "values"                  => "values",
      "values_method"           => "values method",
      "values_method_options"   => "values method options",
      "options"                 => "options",
      "label"                   => "label",
      "position"                => 1,
      "validator_type"          => "validator_type",
      "validator_rule"          => "validator_rule",
      "reconfigurable"          => nil
    }
  end

  describe "#serialize" do
    it "serializes the dialog_field" do
      dialog_field_serializer.serialize(dialog_field).should == expected_serialized_values
    end
  end
end

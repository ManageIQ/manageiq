require "spec_helper"

describe DialogGroupSerializer do
  let(:dialog_field_serializer) { instance_double("DialogFieldSerializer") }

  let(:dialog_group_serializer) { described_class.new(dialog_field_serializer) }

  describe "#serialize" do
    let(:dialog_field) { DialogField.new }
    let(:dialog_group) do
      DialogGroup.new(
        :description            => "description",
        :dialog_fields          => [dialog_field],
        :display                => "display",
        :display_method         => "display method",
        :display_method_options => "display method options",
        :label                  => "label",
        :position               => 1)
    end

    let(:expected_serialized_values) do
      {
        "description"            => "description",
        "dialog_fields"          => ["serialized_dialog_fields"],
        "display"                => "display",
        "display_method"         => "display method",
        "display_method_options" => "display method options",
        "label"                  => "label",
        "position"               => 1
      }
    end

    before do
      dialog_field_serializer.stub(:serialize).with(dialog_field).and_return("serialized_dialog_fields")
    end

    it "serializes the dialog_group" do
      dialog_group_serializer.serialize(dialog_group).should == expected_serialized_values
    end
  end
end

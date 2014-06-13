require "spec_helper"

describe DialogTabSerializer do
  let(:dialog_group_serializer) { instance_double("DialogGroupSerializer") }

  let(:dialog_tab_serializer) { described_class.new(dialog_group_serializer) }

  describe "#serialize" do
    let(:dialog_group) { DialogGroup.new }
    let(:dialog_tab) do
      DialogTab.new(
        :description            => "description",
        :dialog_groups          => [dialog_group],
        :display                => "display",
        :label                  => "label",
        :display_method         => "display method",
        :display_method_options => "display method options",
        :position               => 1
      )
    end

    let(:expected_serialized_values) do
      {
        "description"            => "description",
        "dialog_groups"          => ["serialized dialog group"],
        "display"                => "display",
        "display_method"         => "display method",
        "display_method_options" => "display method options",
        "label"                  => "label",
        "position"               => 1
      }
    end

    before do
      dialog_group_serializer.stub(:serialize).with(dialog_group).and_return("serialized dialog group")
    end

    it "serializes the dialog tab" do
      dialog_tab_serializer.serialize(dialog_tab).should == expected_serialized_values
    end
  end
end

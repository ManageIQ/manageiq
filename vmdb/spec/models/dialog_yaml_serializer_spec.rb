require "spec_helper"
require "dialog_tab_serializer"

describe DialogYamlSerializer do
  let(:dialog_tab_serializer) { instance_double("DialogTabSerializer") }

  let(:dialog_yaml_serializer) { described_class.new(dialog_tab_serializer) }

  describe "#serialize" do
    let(:buttons) { "the buttons" }
    let(:description) { "the description" }
    let(:dialog_tab1) { DialogTab.new }
    let(:dialog_tab2) { DialogTab.new }
    let(:label) { "the label" }

    let(:dialog) do
      Dialog.new(
        :buttons     => buttons,
        :description => description,
        :dialog_tabs => [dialog_tab1, dialog_tab2],
        :label       => label
      )
    end

    let(:dialogs) { [dialog] }

    let(:expected_yaml) do
      [{
        "description" => description,
        "buttons"     => buttons,
        "label"       => label,
        "dialog_tabs" => ["serialized_dialog1", "serialized_dialog2"]
      }].to_yaml
    end

    before do
      dialog_tab_serializer.stub(:serialize).with(dialog_tab1).and_return("serialized_dialog1")
      dialog_tab_serializer.stub(:serialize).with(dialog_tab2).and_return("serialized_dialog2")
    end

    it "serializes the dialog" do
      dialog_yaml_serializer.serialize(dialogs).should == expected_yaml
    end
  end
end

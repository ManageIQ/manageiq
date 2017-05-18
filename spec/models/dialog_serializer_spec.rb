describe DialogSerializer do
  let(:dialog_tab_serializer) { double("DialogTabSerializer") }
  let(:dialog_serializer) { described_class.new(dialog_tab_serializer) }

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

    let(:expected_data) do
      [{
        "description"  => description,
        "buttons"      => buttons,
        "label"        => label,
        "blueprint_id" => nil,
        "dialog_tabs"  => %w(serialized_dialog1 serialized_dialog2)
      }]
    end

    before do
      allow(dialog_tab_serializer).to receive(:serialize).with(dialog_tab1, boolean).and_return("serialized_dialog1")
      allow(dialog_tab_serializer).to receive(:serialize).with(dialog_tab2, boolean).and_return("serialized_dialog2")
    end

    it "serializes the dialog" do
      expect(dialog_serializer.serialize(dialogs)).to eq(expected_data)
    end
  end
end

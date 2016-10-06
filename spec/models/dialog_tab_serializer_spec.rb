describe DialogTabSerializer do
  let(:dialog_group_serializer) { double("DialogGroupSerializer") }
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
      allow(dialog_group_serializer).to receive(:serialize).with(dialog_group, boolean)
        .and_return("serialized dialog group")
    end

    it "serializes the dialog tab" do
      expect(dialog_tab_serializer.serialize(dialog_tab)).to eq(expected_serialized_values)
    end

    it 'serializes the dialog tab with all attributes' do
      expect(dialog_tab_serializer.serialize(dialog_tab, true))
        .to eq(expected_serialized_values.merge(
                 'created_at' => nil,
                 'dialog_id'  => nil,
                 'id'         => nil,
                 'updated_at' => nil
        ))
    end
  end
end

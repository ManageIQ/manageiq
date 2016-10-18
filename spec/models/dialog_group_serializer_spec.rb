describe DialogGroupSerializer do
  let(:dialog_field_serializer) { double("DialogFieldSerializer") }
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
      allow(dialog_field_serializer)
        .to receive(:serialize).with(dialog_field, boolean).and_return("serialized_dialog_fields")
    end

    it "serializes the dialog_group" do
      expect(dialog_group_serializer.serialize(dialog_group)).to eq(expected_serialized_values)
    end

    it 'serializes the dialog with all attributes' do
      expect(dialog_group_serializer.serialize(dialog_group, true))
        .to eq(expected_serialized_values.merge(
                 'created_at'    => nil,
                 'dialog_tab_id' => nil,
                 'id'            => nil,
                 'updated_at'    => nil
        ))
    end
  end
end

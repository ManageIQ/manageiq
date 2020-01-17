RSpec.describe DialogGroup do
  let(:dialog_group) { FactoryBot.build(:dialog_group, :label => 'group') }
  context "#validate_children" do
    it "fails without element" do
      expect { dialog_group.save! }
        .to raise_error(ActiveRecord::RecordInvalid, /Box group must have at least one Element/)
    end

    it "validates with at least one element" do
      dialog_group.dialog_fields << FactoryBot.create(:dialog_field, :label => 'field 1', :name => 'field1')
      expect_any_instance_of(DialogField).to receive(:valid?)
      expect(dialog_group.errors.full_messages).to be_empty
      dialog_group.validate_children
    end
  end

  context "#dialog_fields" do
    # other tests are in dialog_spec.rb
    it "returns [] even when no dialog_tab" do
      expect(dialog_group.dialog_fields).to be_empty
    end
  end

  describe '#update_dialog_fields' do
    let(:dialog_fields) { FactoryBot.create_list(:dialog_field, 2) }
    let(:dialog_group) { FactoryBot.create(:dialog_group, :dialog_fields => dialog_fields) }
    let(:resource_action) { FactoryBot.create(:resource_action) }

    context 'a collection of dialog fields containing two objects with ids and one without an id' do
      let(:updated_fields) do
        [
          { 'id' => dialog_fields.first.id, 'label' => 'updated_field_label', 'dialog_field_responders' => []},
          { 'id' => dialog_fields.last.id, 'label' => 'updated_field_label', 'dialog_field_responders' => []},
          { 'name' => 'new field', 'label' => 'new field label', 'dialog_field_responders' => [] }
        ]
      end
      it 'creates or updates the dialog fields' do
        dialog_group.update_dialog_fields(updated_fields)
        dialog_group.reload
        expect(dialog_group.dialog_fields.collect(&:label))
          .to match_array(['updated_field_label', 'updated_field_label', 'new field label'])
      end
    end

    context 'a collection of dialog fields with resource actions' do
      let(:updated_fields) do
        [
          { 'id' => dialog_fields.first.id, 'label' => 'updated_field_label', 'resource_action' =>
            {'resource_type' => 'DialogField', 'ae_attributes' => {}}, 'dialog_field_responders' => [] },
          { 'id' => dialog_fields.last.id, 'label' => 'updated_field_label', 'resource_action' =>
            {'id' => resource_action.id, 'resource_type' => 'DialogField'}, 'dialog_field_responders' => []}
        ]
      end
      it 'updates the dialog fields' do
        dialog_group.update_dialog_fields(updated_fields)
        dialog_group.reload
        expect(dialog_group.dialog_fields.collect(&:resource_action).collect(&:resource_type))
          .to match_array(%w(DialogField DialogField))
      end
    end

    context 'with a dialog field removed from the dialog fields' do
      let(:updated_fields) do
        [
          { 'id' => dialog_fields.first.id, 'dialog_field_responders' => [] }
        ]
      end

      it 'deletes the removed dialog field' do
        expect do
          dialog_group.update_dialog_fields(updated_fields)
        end.to change(dialog_group.reload.dialog_fields, :count).by(-1)
      end
    end

    context 'it symbolizes a dialog fields options' do
      let(:updated_fields) do
        [{ 'name' => 'new', 'label' => 'new field label', 'type' => 'DialogFieldTagControl', 'options' =>
          { 'name' => 'foo', 'description' => 'bar'} }]
      end

      it 'dialog_field.options has symbolized keys' do
        dialog_group.update_dialog_fields(updated_fields)
        dialog_group.reload
        expect(dialog_group.dialog_fields.first.options).to eq(:name        => 'foo',
                                                               :description => 'bar',
                                                               :category_id => nil)
      end
    end
  end
end

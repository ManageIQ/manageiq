RSpec.describe DialogTab do
  let(:dialog_tab) { FactoryBot.build(:dialog_tab, :label => 'tab') }
  context "#validate_children" do
    it "fails without box" do
      expect { dialog_tab.save! }
        .to raise_error(ActiveRecord::RecordInvalid, /tab must have at least one Box/)
    end

    it "validates with box" do
      dialog_tab.dialog_groups << FactoryBot.create(:dialog_group, :label => 'box')
      expect_any_instance_of(DialogGroup).to receive(:valid?)
      expect(dialog_tab.errors.full_messages).to be_empty
      dialog_tab.validate_children
    end
  end

  context "#dialog_fields" do
    # other tests are in dialog_spec.rb
    it "returns [] even when no dialog_groups" do
      expect(dialog_tab.dialog_fields).to be_empty
    end

    it "returns [] when empty dialog_group " do
      dialog_tab.dialog_groups << FactoryBot.build(:dialog_group)
      expect(dialog_tab.dialog_fields).to be_empty
    end
  end

  describe '#update_dialog_groups' do
    let(:dialog_fields) { FactoryBot.create_list(:dialog_field, 2) }
    let(:dialog_groups) { FactoryBot.create_list(:dialog_group, 2) }
    let(:dialog_tab) { FactoryBot.create(:dialog_tab, :dialog_groups => dialog_groups) }

    before do
      dialog_groups.each_with_index { |group, index| group.dialog_fields << dialog_fields[index] }
    end

    context 'a collection of dialog groups containing two objects with ids and one without an id' do
      let(:updated_groups) do
        [
          { 'id'            => dialog_groups.first.id,
            'label'         => 'updated_label',
            'dialog_fields' => [{ 'id' => dialog_fields.first.id}]
          },
          { 'id'            => dialog_groups.last.id,
            'label'         => 'updated_label',
            'dialog_fields' => [{'id' => dialog_fields.last.id}]
          },
          {
            'label'         => 'a new label',
            'dialog_fields' => [{'name' => 'field name', 'label' => 'field label'}]
          }
        ]
      end

      it 'updates the dialog groups with an id' do
        dialog_tab.update_dialog_groups(updated_groups)

        dialog_tab.reload
        expect(dialog_tab.dialog_groups.collect(&:label))
          .to match_array(['updated_label', 'updated_label', 'a new label'])
      end

      it 'creates a new dialog group from the dialog group without an id' do
        expect do
          dialog_tab.update_dialog_groups(updated_groups)
        end.to change(dialog_tab.reload.dialog_groups, :count).by(1)
      end
    end

    context 'with a dialog group removed from the dialog groups' do
      let(:updated_groups) do
        [
          { 'id' => dialog_groups.first.id, 'dialog_fields' => []}
        ]
      end

      it 'deletes the removed dialog group' do
        expect do
          dialog_tab.update_dialog_groups(updated_groups)
        end.to change(dialog_tab.reload.dialog_groups, :count).by(-1)
      end
    end
  end
end

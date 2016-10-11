describe DialogTab do
  let(:dialog_tab) { FactoryGirl.build(:dialog_tab, :label => 'tab') }
  context "#validate_children" do

    it "fails without box" do
      expect { dialog_tab.save! }
        .to raise_error(ActiveRecord::RecordInvalid, /tab must have at least one Box/)
    end

    it "validates with box" do
      dialog_tab.dialog_groups << FactoryGirl.create(:dialog_group, :label => 'box')
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
      dialog_tab.dialog_groups << FactoryGirl.build(:dialog_group)
      expect(dialog_tab.dialog_fields).to be_empty
    end
  end

  context '#update_dialog_groups' do
    before(:each) do
      @dialog_tab = FactoryGirl.create(:dialog_tab)
      @dialog_groups = FactoryGirl.create_list(:dialog_group, 2)
      @dialog_groups.first.dialog_fields << FactoryGirl.create_list(:dialog_field, 1)
      @dialog_tab.dialog_groups << @dialog_groups
    end

    it 'deletes a dialog group' do
      groups = [
        {
          'id' => @dialog_groups.first.id,
          'dialog_fields' => []
        }
      ]
      expect do
        @dialog_tab.update_dialog_groups(groups)
      end.to change(@dialog_tab.reload.dialog_groups, :count).by(-1)
    end

    it 'adds a new dialog group' do
      groups = [
        {
          'id' => @dialog_groups.first.id,
          'dialog_fields' => []
        },
        {
          'id' => @dialog_groups.last.id,
          'dialog_fields' => []
        },
        {
          'label' => 'new group',
          'dialog_fields' => [ { 'name' => 'field', 'label' => 'field' } ]
        }
      ]

      expect do
        @dialog_tab.update_dialog_groups(groups)
      end.to change(@dialog_tab.reload.dialog_groups, :count).by(1)
    end

    it 'updates a dialog group' do
      groups = [
        {
          'id' => @dialog_groups.first.id,
          'label' => 'new label',
          'dialog_fields' => []
        },
        {
          'id' => @dialog_groups.last.id,
          'dialog_fields' => []
        }
      ]

      expect do
        @dialog_tab.update_dialog_groups(groups)
      end.to change(@dialog_groups.first.reload, :label)
    end
  end
end

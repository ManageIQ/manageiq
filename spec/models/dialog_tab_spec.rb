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
end

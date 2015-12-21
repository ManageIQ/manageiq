require 'spec_helper'

describe DialogTab do
  context "#validate_children" do
    let(:dialog_tab) { FactoryGirl.build(:dialog_tab, :label => 'tab') }

    it "fails without box" do
      expect { dialog_tab.save! }.to raise_error
    end

    it "validates with box" do
      dialog_tab.dialog_groups << FactoryGirl.create(:dialog_group, :label => 'box')
      expect_any_instance_of(DialogGroup).to receive(:valid?)
      expect(dialog_tab.errors.full_messages).to be_empty
      dialog_tab.validate_children
    end
  end
end

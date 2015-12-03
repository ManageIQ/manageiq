require 'spec_helper'

describe DialogGroup do
  context "#validate_children" do
    let(:dialog_group) { FactoryGirl.build(:dialog_group, :label => 'group') }

    it "fails without element" do
      expect { dialog_group.save! }.to raise_error
    end

    it "validates with at least one element" do
      dialog_group.add_resource(FactoryGirl.create(:dialog_field, :label => 'field 1', :name => 'field1'))
      expect_any_instance_of(DialogField).to receive(:valid?)
      expect(dialog_group.errors.full_messages).to be_empty
      dialog_group.validate_children
    end
  end
end

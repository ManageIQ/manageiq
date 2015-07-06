require "spec_helper"

describe MiqPolicy do
  context "Testing edge cases on conditions" do
    # The conditions reflection on MiqPolicy is affected when called through a
    # belongs_to or has_one, which is used under the covers in MiqSet.  This
    # test verifies that changing things under the covers doesn't affect
    # calling conditions.

    before(:each) do
      @ps = FactoryGirl.create(:miq_policy_set)
      @p  = FactoryGirl.create(:miq_policy)
      @ps.add_member(@p)
    end

    it "should return the correct conditions" do
      @ps.miq_policies.first.conditions.should == []
      @p.conditions.should == []
    end
  end

  context "#description=" do
    subject { FactoryGirl.create(:miq_policy, :description => @description) }

    it "should keep the description < 255" do
      @description = "a" * 30
      subject.description.length.should == 30
    end

    it "should raise an error with empty description" do
      @description = nil
      lambda { subject.description }.should raise_error(ActiveRecord::RecordInvalid, "Validation failed: Description can't be blank")
    end

    it "should raise an error when description is reset to empty" do
      @description = "a" * 30
      subject.description = nil
      lambda { subject.save! }.should raise_error(ActiveRecord::RecordInvalid, "Validation failed: Description can't be blank")
    end
  end
end

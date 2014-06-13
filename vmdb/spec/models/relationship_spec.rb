require "spec_helper"

describe Relationship do
  before(:each) do
    @rel = FactoryGirl.create(:relationship_vm_vmware)
  end

  context "#filtered?" do
    it "with of_type" do
      @rel.should_not be_filtered(["VmOrTemplate"], [])
      @rel.should_not be_filtered(["VmOrTemplate", "Host"], [])
      @rel.should_not be_filtered(["Host", "VmOrTemplate"], [])
      @rel.should     be_filtered(["Host"], [])
    end

    it "with except_type" do
      @rel.should     be_filtered([], ["VmOrTemplate"])
      @rel.should     be_filtered([], ["VmOrTemplate", "Host"])
      @rel.should     be_filtered([], ["Host", "VmOrTemplate"])
      @rel.should_not be_filtered([], ["Host"])
    end

    it "with both of_type and except_type" do
      @rel.should_not be_filtered(["VmOrTemplate"], ["Host"])
      @rel.should     be_filtered(["Host"], ["VmOrTemplate"])
    end
  end
end

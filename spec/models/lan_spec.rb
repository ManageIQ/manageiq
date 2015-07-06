require "spec_helper"

describe Lan do
  before(:each) do
    @lan      = FactoryGirl.create(:lan)
    @vm       = FactoryGirl.create(:vm_vmware,       :hardware => FactoryGirl.create(:hardware, :guest_devices => [FactoryGirl.create(:guest_device_nic, :lan => @lan)]))
    @template = FactoryGirl.create(:template_vmware, :hardware => FactoryGirl.create(:hardware, :guest_devices => [FactoryGirl.create(:guest_device_nic, :lan => @lan)]))
  end

  it "#vms_and_templates" do
    @lan.vms_and_templates.should match_array [@vm, @template]
  end

  it "#vms" do
    @lan.vms.should == [@vm]
  end

  it "#miq_templates" do
    @lan.miq_templates.should == [@template]
  end
end

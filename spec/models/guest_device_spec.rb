require "spec_helper"

describe GuestDevice do
  before(:each) do
    @vm_gd = FactoryGirl.create(:guest_device_nic)
    @vm    = FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :guest_devices => [@vm_gd]))

    @template_gd = FactoryGirl.create(:guest_device_nic)
    @template    = FactoryGirl.create(:template_vmware, :hardware => FactoryGirl.create(:hardware, :guest_devices => [@template_gd]))

    @host_gd = FactoryGirl.create(:guest_device_nic)
    @host    = FactoryGirl.create(:host, :hardware => FactoryGirl.create(:hardware, :guest_devices => [@host_gd]))
  end

  it "#vm_or_template" do
    @vm_gd.vm_or_template.should       == @vm
    @template_gd.vm_or_template.should == @template
    @host_gd.vm_or_template.should     be_nil
  end

  it "#vm" do
    @vm_gd.vm.should       == @vm
    @template_gd.vm.should be_nil
    @host_gd.vm.should     be_nil
  end

  it "#miq_template" do
    @vm_gd.miq_template.should       be_nil
    @template_gd.miq_template.should == @template
    @host_gd.miq_template.should     be_nil
  end

  it "#host" do
    @vm_gd.host.should       be_nil
    @template_gd.host.should be_nil
    @host_gd.host.should     == @host
  end
end

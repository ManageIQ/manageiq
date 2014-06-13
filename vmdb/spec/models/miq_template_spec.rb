require "spec_helper"

describe MiqTemplate do
  it ".corresponding_model" do
    described_class.corresponding_model.should == Vm
    TemplateVmware.corresponding_model.should == VmVmware
    TemplateRedhat.corresponding_model.should == VmRedhat
  end

  it ".corresponding_vm_model" do
    described_class.corresponding_vm_model.should == Vm
    TemplateVmware.corresponding_vm_model.should == VmVmware
    TemplateRedhat.corresponding_vm_model.should == VmRedhat
  end

  context "#template=" do
    before(:each) { @template = FactoryGirl.create(:template_vmware) }

    it "true" do
      @template.update_attribute(:template, true)
      @template.type.should     == "TemplateVmware"
      @template.template.should == true
      @template.state.should    == "never"
      lambda { @template.reload }.should_not raise_error
      lambda { VmVmware.find(@template.id) }.should raise_error ActiveRecord::RecordNotFound
    end

    it "false" do
      @template.update_attribute(:template, false)
      @template.type.should     == "VmVmware"
      @template.template.should == false
      @template.state.should    == "unknown"
      lambda { @template.reload }.should raise_error ActiveRecord::RecordNotFound
      lambda { VmVmware.find(@template.id) }.should_not raise_error
    end
  end

  it ".supports_kickstart_provisioning?" do
    TemplateAmazon.supports_kickstart_provisioning?.should be_false
    TemplateRedhat.supports_kickstart_provisioning?.should be_true
    TemplateVmware.supports_kickstart_provisioning?.should be_false
  end

  it "#supports_kickstart_provisioning?" do
    TemplateAmazon.new.supports_kickstart_provisioning?.should be_false
    TemplateRedhat.new.supports_kickstart_provisioning?.should be_true
    TemplateVmware.new.supports_kickstart_provisioning?.should be_false
  end

end

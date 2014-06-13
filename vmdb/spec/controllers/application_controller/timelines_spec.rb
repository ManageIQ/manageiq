require "spec_helper"

describe ApplicationController do

  before :each do
    controller.instance_variable_set(:@sb, {})
    vm = FactoryGirl.create(:vm_vmware)
    controller.instance_variable_set(:@record, vm)
  end

  context "VDI Activity option in Event Groups pull down" do
    it "removes VDI Activity option if vdi flag is not set" do
      cfg = {:product => {}}
      controller.stub(:get_vmdb_config).and_return(cfg)
      controller.send(:tl_build_init_options)
      assigns(:tl_options)[:groups].should_not include("VDI Activity")
    end

    it "verify presence of VDI Activity option if vdi flag is set" do
      cfg = {:product => {:vdi => true}}
      controller.stub(:get_vmdb_config).and_return(cfg)
      controller.send(:tl_build_init_options)
      assigns(:tl_options)[:groups].should include("VDI Activity")
    end
  end
end

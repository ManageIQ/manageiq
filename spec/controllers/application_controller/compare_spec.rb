require "spec_helper"

describe ApplicationController do
  context "#drift_history" do
    it "resets @display to main" do
      vm = FactoryGirl.create(:vm_vmware, :name => "My VM")
      controller.instance_variable_set(:@display, "vms")
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@drift_obj, vm)
      controller.stub(:identify_obj)
      controller.stub(:drift_state_timestamps)
      controller.stub(:drop_breadcrumb)
      controller.should_receive(:render)
      controller.send(:drift_history)
      assigns(:display).should eq("main")
    end
  end
end

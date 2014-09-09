require "spec_helper"

describe CloudTenantController do
  context "#button" do
    it "when Instance Retire button is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "instance_retire")
      controller.should_receive(:retirevms).once
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when Instance Tag is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "instance_tag")
      controller.should_receive(:tag).with(VmOrTemplate)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end
  end
end

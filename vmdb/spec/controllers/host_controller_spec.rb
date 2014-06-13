require "spec_helper"

describe HostController do
  context "#button" do
    it "when VM Right Size Recommendations is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "vm_right_size"})
      controller.should_receive(:vm_right_size)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Migrate is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "vm_migrate"})
      controller.should_receive(:prov_redirect).with("migrate")
      controller.should_receive(:render)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Retire is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "vm_retire"})
      controller.should_receive(:retirevms).once
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Manage Policies is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "vm_protect"})
      controller.should_receive(:assign_policies).with(VmOrTemplate)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when MiqTemplate Manage Policies is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "miq_template_protect"})
      controller.should_receive(:assign_policies).with(VmOrTemplate)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Tag is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "vm_tag"})
      controller.should_receive(:tag).with(VmOrTemplate)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when MiqTemplate Tag is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "miq_template_tag"})
      controller.should_receive(:tag).with(VmOrTemplate)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when Custom Button is pressed" do
      host = FactoryGirl.create(:host)
      custom_button = FactoryGirl.create(:custom_button, :applies_to_class => "Host")
      d = FactoryGirl.create(:dialog, :label => "Some Label")
      dt = FactoryGirl.create(:dialog_tab, :label => "Some Tab")
      d.add_resource(dt, {:order => 0})
      ra = FactoryGirl.create(:resource_action, :dialog_id => d.id)
      custom_button.resource_action = ra
      custom_button.save
      user = FactoryGirl.create(:user, :userid => 'wilma')
      session[:userid] = "wilma"
      controller.should_receive(:render)
      post :button, :pressed => "custom_button", :id => host.id, :button_id => custom_button.id
      controller.send(:flash_errors?).should_not be_true
    end

    it "when Drift button is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "common_drift"})
      controller.should_receive(:drift_analysis)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end
  end
end

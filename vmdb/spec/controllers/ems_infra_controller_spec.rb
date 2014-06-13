require "spec_helper"

describe EmsInfraController do
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

    it "should set correct VM for right-sizing when on list of VM's of another CI" do
      set_user_privileges
      ems_infra = FactoryGirl.create(:ext_management_system)
      post :button, :pressed => "vm_right_size", :id => ems_infra.id, :display => 'vms', :check_10r839 => '1'
      controller.send(:flash_errors?).should_not be_true
      response.body.should include("/vm/right_size/#{ActiveRecord::Base.uncompress_id('10r839')}")
    end

    it "when Host Analyze then Check Compliance is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "host_analyze_check_compliance"})
      controller.stub(:show)
      controller.should_receive(:analyze_check_compliance_hosts)
      controller.should_receive(:render)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end
  end
end

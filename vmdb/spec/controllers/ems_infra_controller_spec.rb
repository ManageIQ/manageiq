require "spec_helper"

describe EmsInfraController do
  context "#button" do
    before(:each) do
      set_user_privileges
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone
    end

    it "when VM Right Size Recommendations is pressed" do
      controller.should_receive(:vm_right_size)
      post :button, :pressed => "vm_right_size", :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Migrate is pressed" do
      controller.should_receive(:prov_redirect).with("migrate")
      post :button, :pressed => "vm_migrate", :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Retire is pressed" do
      controller.should_receive(:retirevms).once
      post :button, :pressed => "vm_retire", :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Manage Policies is pressed" do
      controller.should_receive(:assign_policies).with(VmOrTemplate)
      post :button, :pressed => "vm_protect", :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when MiqTemplate Manage Policies is pressed" do
      controller.should_receive(:assign_policies).with(VmOrTemplate)
      post :button, :pressed => "miq_template_protect", :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Tag is pressed" do
      controller.should_receive(:tag).with(VmOrTemplate)
      post :button, :pressed => "vm_tag", :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when MiqTemplate Tag is pressed" do
      controller.should_receive(:tag).with(VmOrTemplate)
      post :button, :pressed => 'miq_template_tag', :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "should set correct VM for right-sizing when on list of VM's of another CI" do
      ems_infra = FactoryGirl.create(:ext_management_system)
      post :button, :pressed => "vm_right_size", :id => ems_infra.id, :display => 'vms', :check_10r839 => '1'
      controller.send(:flash_errors?).should_not be_true
      response.body.should include("/vm/right_size/#{ActiveRecord::Base.uncompress_id('10r839')}")
    end

    it "when Host Analyze then Check Compliance is pressed" do
      controller.should_receive(:analyze_check_compliance_hosts)
      post :button, :pressed => "host_analyze_check_compliance", :format => :js
      controller.send(:flash_errors?).should_not be_true
    end
  end
end

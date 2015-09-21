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

    it "when VM Migrate is pressed" do
      vm = FactoryGirl.create(:vm_vmware)
      ems = FactoryGirl.create("ems_vmware")
      post :button, :pressed => "vm_migrate", :format => :js, "check_#{vm.id}" => 1, :id => ems.id
      controller.send(:flash_errors?).should_not be_true
      response.body.should include("/miq_request/prov_edit?")
      expect(response.status).to eq(200)
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

  describe "#create" do
    before do
      EvmSpecHelper.seed_specific_product_features("ems_infra_new")
      feature = MiqProductFeature.find_all_by_identifier(["ems_infra_new"])
      test_user_role  = FactoryGirl.create(:miq_user_role,
                                           :name                 => "test_user_role",
                                           :miq_product_features => feature)
      test_user_group = FactoryGirl.create(:miq_group, :miq_user_role => test_user_role)
      user = FactoryGirl.create(:user, :name => 'test_user', :miq_groups => [test_user_group])

      allow(user).to receive(:server_timezone).and_return("UTC")
      described_class.any_instance.stub(:set_user_time_zone)
      controller.stub(:check_privileges).and_return(true)
      login_as user
    end

    it "adds a new provider" do
      controller.instance_variable_set(:@breadcrumbs, [])
      get :new
      expect(response.status).to eq(200)
      expect(controller.stub(:edit)).to_not be_nil
    end
  end

  describe "#scaling" do

    before do
      set_user_privileges
      @ems = FactoryGirl.create(:ems_openstack_infra_with_stack)
      @orchestration_stack_parameter_compute = FactoryGirl.create(:orchestration_stack_parameter_openstack_infra_compute)

      ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack.any_instance.stub(:raw_status).and_return(["CREATE_COMPLETE", nil])
    end

    it "when values are not changed" do
      post :scaling, :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id
      controller.send(:flash_errors?).should be_true
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should include(_("A value must be changed or provider will not be scaled"))
    end

    it "when values are changed, but exceed number of hosts available" do
      post :scaling, :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id,
           @orchestration_stack_parameter_compute.name => @ems.hosts.count * 2
      controller.send(:flash_errors?).should be_true
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should include(
      _("Assigning #{@ems.hosts.count * 2} but only have #{@ems.hosts.count} hosts available."))
    end

    it "when values are changed, and values do not exceed number of hosts available" do
      ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack.any_instance.stub(:raw_update_stack)
      post :scaling, :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id,
           @orchestration_stack_parameter_compute.name => 2
      controller.send(:flash_errors?).should be_false
      response.body.should include("redirected")
      response.body.should include("show")
      response.body.should include("1+to+2")
    end

    it "when no orchestration stack is available" do
      @ems = FactoryGirl.create(:ems_openstack_infra)
      post :scaling, :id => @ems.id, :scale => "", :orchestration_stack_id => nil
      controller.send(:flash_errors?).should be_true
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should include(_("Orchestration stack could not be found."))
    end

    it "when patch operation fails, an error message should be displayed" do
      ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack.any_instance.stub(:raw_update_stack) { raise _("my error") }
      post :scaling, :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id,
           @orchestration_stack_parameter_compute.name => 2
      controller.send(:flash_errors?).should be_true
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should include(_("Unable to initiate scaling: my error"))
    end

    it "when operation in progress, an error message should be displayed" do
      ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack.any_instance.stub(:raw_status).and_return(["CREATE_IN_PROGRESS", nil])
      post :scaling, :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id,
           @orchestration_stack_parameter_compute.name => 2
      controller.send(:flash_errors?).should be_true
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should include(
        _("Provider is not ready to be scaled, another operation is in progress."))
    end
  end
end

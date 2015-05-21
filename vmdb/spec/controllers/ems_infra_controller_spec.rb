require "spec_helper"

describe EmsInfraController do
  context "#button" do
    before(:each) do
      set_user_privileges
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone
    end

    it "can use the cancel button on create" do
      controller.instance_variable_set(:@edit, {:new => {},
                                                :key => "ems_edit__new"})
      session[:edit] = assigns(:edit)
      controller.stub(:drop_breadcrumb)
      post :create, :button => "cancel"
      expect(response.status).to eq(200)
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

  describe "#scaling" do

    before do
      set_user_privileges
      @ems = FactoryGirl.create(:ems_openstack_infra_with_stack)
      @orchestration_stack_parameter_compute = FactoryGirl.create(:orchestration_stack_parameter_openstack_infra_compute)
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
      OrchestrationStackOpenstackInfra.any_instance.stub(:raw_update_stack)
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
      OrchestrationStackOpenstackInfra.any_instance.stub(:raw_update_stack) { raise _("my error") }
      post :scaling, :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id,
           @orchestration_stack_parameter_compute.name => 2
      controller.send(:flash_errors?).should be_true
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should include(_("Unable to initiate scaling: my error"))
    end
  end

  describe "#scaling osp7 parameter names" do

    before do
      set_user_privileges
      @ems = FactoryGirl.create(:ems_openstack_infra_with_stack_osp7)
      @orchestration_stack_parameter_compute = FactoryGirl.create(:orchestration_stack_parameter_openstack_infra_compute_osp7)
    end

    it "when values are changed, and values do not exceed number of hosts available" do
      OrchestrationStackOpenstackInfra.any_instance.stub(:raw_update_stack)
      post :scaling, :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id,
           @orchestration_stack_parameter_compute.name => 2
      controller.send(:flash_errors?).should be_false
      response.body.should include("redirected")
      response.body.should include("show")
      response.body.should include("1+to+2")
    end
  end
end

describe EmsInfraController do
  context "#button" do
    before(:each) do
      set_user_privileges
      EvmSpecHelper.create_guid_miq_server_zone

      ApplicationController.handle_exceptions = true
    end

    it "when VM Right Size Recommendations is pressed" do
      expect(controller).to receive(:vm_right_size)
      post :button, :params => { :pressed => "vm_right_size", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Migrate is pressed" do
      expect(controller).to receive(:prov_redirect).with("migrate")
      post :button, :params => { :pressed => "vm_migrate", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Migrate is pressed" do
      ems = FactoryGirl.create(:ems_vmware)
      vm = FactoryGirl.create(:vm_vmware, :ext_management_system => ems)
      post :button, :params => { :pressed => "vm_migrate", :format => :js, "check_#{vm.id}" => 1, :id => ems.id }
      expect(controller.send(:flash_errors?)).not_to be_truthy
      expect(response.body).to include("/miq_request/prov_edit?")
      expect(response.status).to eq(200)
    end

    it "when VM Retire is pressed" do
      expect(controller).to receive(:retirevms).once
      post :button, :params => { :pressed => "vm_retire", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Manage Policies is pressed" do
      expect(controller).to receive(:assign_policies).with(VmOrTemplate)
      post :button, :params => { :pressed => "vm_protect", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when MiqTemplate Manage Policies is pressed" do
      expect(controller).to receive(:assign_policies).with(VmOrTemplate)
      post :button, :params => { :pressed => "miq_template_protect", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Tag is pressed" do
      expect(controller).to receive(:tag).with(VmOrTemplate)
      post :button, :params => { :pressed => "vm_tag", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when MiqTemplate Tag is pressed" do
      expect(controller).to receive(:tag).with(VmOrTemplate)
      post :button, :params => { :pressed => 'miq_template_tag', :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "should set correct VM for right-sizing when on list of VM's of another CI" do
      ems_infra = FactoryGirl.create(:ext_management_system)
      post :button, :params => { :pressed => "vm_right_size", :id => ems_infra.id, :display => 'vms', :check_10r839 => '1' }
      expect(controller.send(:flash_errors?)).not_to be_truthy
      expect(response.body).to include("/vm/right_size/#{ApplicationRecord.uncompress_id('10r839')}")
    end

    it "when Host Analyze then Check Compliance is pressed" do
      ems_infra = FactoryGirl.create(:ems_vmware)
      expect(controller).to receive(:analyze_check_compliance_hosts)
      post :button, :params => {:pressed => "host_analyze_check_compliance", :id => ems_infra.id, :format => :js}
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end
  end

  describe "#create" do
    before do
      user = FactoryGirl.create(:user, :features => "ems_infra_new")

      allow(user).to receive(:server_timezone).and_return("UTC")
      allow_any_instance_of(described_class).to receive(:set_user_time_zone)
      allow(controller).to receive(:check_privileges).and_return(true)
      login_as user
    end

    it "adds a new provider" do
      controller.instance_variable_set(:@breadcrumbs, [])
      get :new
      expect(response.status).to eq(200)
      expect(allow(controller).to receive(:edit)).to_not be_nil
    end
  end

  describe "#scaling" do
    before do
      set_user_privileges
      @ems = FactoryGirl.create(:ems_openstack_infra_with_stack)
      @orchestration_stack_parameter_compute = FactoryGirl.create(:orchestration_stack_parameter_openstack_infra_compute)

      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack)
        .to receive(:raw_status).and_return(["CREATE_COMPLETE", nil])
    end

    it "when values are not changed" do
      post :scaling, :params => { :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id }
      expect(controller.send(:flash_errors?)).to be_truthy
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include(
        _("A value must be changed or provider stack will not be updated."))
    end

    it "when values are changed, but exceed number of hosts available" do
      post :scaling, :params => { :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id,
           @orchestration_stack_parameter_compute.name => @ems.hosts.count * 2 }
      expect(controller.send(:flash_errors?)).to be_truthy
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include(
        _("Assigning #{@ems.hosts.count * 2} but only have #{@ems.hosts.count} hosts available."))
    end

    it "when values are changed, and values do not exceed number of hosts available" do
      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack)
        .to receive(:raw_update_stack)
      post :scaling, :params => { :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id,
           @orchestration_stack_parameter_compute.name => 2 }
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(response.body).to include("redirected")
      expect(response.body).to include("show")
      expect(response.body).to include("1+to+2")
    end

    it "when no orchestration stack is available" do
      @ems = FactoryGirl.create(:ems_openstack_infra)
      post :scaling, :params => { :id => @ems.id, :scale => "", :orchestration_stack_id => nil }
      expect(controller.send(:flash_errors?)).to be_truthy
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include(_("Orchestration stack could not be found."))
    end

    it "when patch operation fails, an error message should be displayed" do
      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack)
        .to receive(:raw_update_stack) { raise _("my error") }
      post :scaling, :params => { :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id,
           @orchestration_stack_parameter_compute.name => 2 }
      expect(controller.send(:flash_errors?)).to be_truthy
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include(_("Unable to initiate scaling: my error"))
    end

    it "when operation in progress, an error message should be displayed" do
      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack)
        .to receive(:raw_status).and_return(["CREATE_IN_PROGRESS", nil])
      post :scaling, :params => { :id => @ems.id, :scale => "", :orchestration_stack_id => @ems.orchestration_stacks.first.id,
           @orchestration_stack_parameter_compute.name => 2 }
      expect(controller.send(:flash_errors?)).to be_truthy
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include(
        _("Provider stack is not ready to be updated, another operation is in progress."))
    end
  end

  describe "#scaledown" do
    before do
      set_user_privileges
      @ems = FactoryGirl.create(:ems_openstack_infra_with_stack_and_compute_nodes)

      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack)
        .to receive(:raw_status).and_return(["CREATE_COMPLETE", nil])
    end

    it "when no compute hosts are selected" do
      post :scaledown, :params => {:id => @ems.id, :scaledown => "",
           :orchestration_stack_id => @ems.orchestration_stacks.first.id, :host_ids => []}
      expect(controller.send(:flash_errors?)).to be_truthy
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include(_("No compute hosts were selected for scale down."))
    end

    it "when values are changed, but selected host is in incorrect state" do
      post :scaledown, :params => {:id => @ems.id, :scaledown => "",
           :orchestration_stack_id => @ems.orchestration_stacks.first.id, :host_ids => [@ems.hosts[0].id]}
      expect(controller.send(:flash_errors?)).to be_truthy
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include(
        _("Not all hosts can be removed from the deployment."))
    end

    it "when values are changed, and selected host is in correct state" do
      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack)
        .to receive(:raw_update_stack)
      post :scaledown, :params => {:id => @ems.id, :scaledown => "",
           :orchestration_stack_id => @ems.orchestration_stacks.first.id, :host_ids => [@ems.hosts[1].id]}
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(response.body).to include("redirected")
      expect(response.body).to include("show")
      expect(response.body).to include("down+to+1")
    end

    it "when no orchestration stack is available" do
      @ems = FactoryGirl.create(:ems_openstack_infra)
      post :scaledown, :params => {:id => @ems.id, :scaledown => "", :orchestration_stack_id => nil}
      expect(controller.send(:flash_errors?)).to be_truthy
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include(_("Orchestration stack could not be found."))
    end

    it "when patch operation fails, an error message should be displayed" do
      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack)
        .to receive(:raw_update_stack) { raise _("my error") }
      post :scaledown, :params => {:id => @ems.id, :scaledown => "",
           :orchestration_stack_id => @ems.orchestration_stacks.first.id, :host_ids => [@ems.hosts[1].id]}
      expect(controller.send(:flash_errors?)).to be_truthy
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include(_("Unable to initiate scaling: my error"))
    end

    it "when operation in progress, an error message should be displayed" do
      allow_any_instance_of(ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack)
        .to receive(:raw_status).and_return(["CREATE_IN_PROGRESS", nil])
      post :scaledown, :params => {:id => @ems.id, :scaledown => "",
           :orchestration_stack_id => @ems.orchestration_stacks.first.id, :host_ids => [@ems.hosts[1].id]}
      expect(controller.send(:flash_errors?)).to be_truthy
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include(
        _("Provider stack is not ready to be updated, another operation is in progress."))
    end
  end

  describe "#show" do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      login_as FactoryGirl.create(:user)
      @ems = FactoryGirl.create(:ems_vmware)
    end

    let(:url_params) { {} }

    subject { get :show, :params => {:id => @ems.id}.merge(url_params) }

    context "display=timeline" do
      let(:url_params) { {:display => 'timeline'} }
      it { is_expected.to have_http_status 200 }
    end

    context "render listnav partial" do
      render_views

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_ems_infra")
      end
    end
  end

  describe "#show_list" do
    before(:each) do
      set_user_privileges
      FactoryGirl.create(:ems_vmware)
      get :show_list
    end
    it { expect(response.status).to eq(200) }

  end

  describe "UI interactions in the form" do
    render_views
    context "#form_field_changed" do
      before do
        set_user_privileges
        EvmSpecHelper.create_guid_miq_server_zone
      end

      it "retains the name field when server emstype is selected from the dropdown" do
        ems = ManageIQ::Providers::InfraManager.new
        controller.instance_variable_set(:@ems, ems)
        controller.send(:set_form_vars)
        edit = controller.instance_variable_get(:@edit)
        edit[:new][:name] = "abc"
        edit[:ems_types] = {"scvmm"           => "Microsoft System Center VMM",
                            "openstack_infra" => "OpenStack Platform Director",
                            "rhevm"           => "Red Hat Enterprise Virtualization Manager",
                            "vmwarews"        => "VMware vCenter"}
        controller.instance_variable_set(:@edit, edit)
        post :form_field_changed, :params => { :id => "new", :server_emstype => "scvmm" }
        edit = controller.instance_variable_get(:@edit)
        expect(edit[:new][:name]).to eq('abc')
        expect(response.body).to include('input type=\"text\" name=\"name\" id=\"name\" value=\"abc\"')
      end
    end
  end

  describe "breadcrumbs path on a 'show' page of an Infrastructure Provider accessed from Dashboard maintab" do
    before do
      set_user_privileges
      EvmSpecHelper.create_guid_miq_server_zone
    end
    context "when previous breadcrumbs path contained 'Cloud Providers'" do
      it "shows 'Infrastructure Providers -> (Summary)' breadcrumb path" do
        ems = FactoryGirl.create("ems_vmware")
        get :show, :params => { :id => ems.id }
        breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
        expect(breadcrumbs).to eq([{:name => "Infrastructure Providers",
                                    :url  => "/ems_infra/show_list?page=&refresh=y"},
                                   {:name => "#{ems.name} (Summary)",
                                    :url  => "/ems_infra/#{ems.id}"}])
      end
    end
  end
end

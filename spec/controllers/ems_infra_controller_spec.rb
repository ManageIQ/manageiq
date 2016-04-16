describe EmsInfraController do
  let!(:server) { EvmSpecHelper.local_miq_server(:zone => zone) }
  let(:zone)   { FactoryGirl.build(:zone) }
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

  describe "#build_credentials" do
    before(:each) do
      @ems = FactoryGirl.create(:ems_openstack_infra)
    end
    context "#build_credentials only contains credentials that it supports and has a username for in params" do
      let(:default_creds) { {:userid => "default_userid", :password => "default_password"} }
      let(:amqp_creds)    { {:userid => "amqp_userid",    :password => "amqp_password"} }
      let(:ssh_keypair_creds)  { {:userid => "ssh_keypair_userid", :auth_key => "ssh_keypair_password"} }

      it "uses the passwords from params for validation if they exist" do
        controller.instance_variable_set(:@_params,
                                         :default_userid       => default_creds[:userid],
                                         :default_password     => default_creds[:password],
                                         :amqp_userid          => amqp_creds[:userid],
                                         :amqp_password        => amqp_creds[:password],
                                         :ssh_keypair_userid   => ssh_keypair_creds[:userid],
                                         :ssh_keypair_password => ssh_keypair_creds[:auth_key])
        expect(@ems).to receive(:supports_authentication?).with(:amqp).and_return(true)
        expect(@ems).to receive(:supports_authentication?).with(:ssh_keypair).and_return(true)
        expect(@ems).to receive(:supports_authentication?).with(:oauth)
        expect(@ems).to receive(:supports_authentication?).with(:auth_key)
        expect(controller.send(:build_credentials, @ems)).to eq(:default     => default_creds,
                                                                :amqp        => amqp_creds,
                                                                :ssh_keypair => ssh_keypair_creds)
      end

      it "uses the stored passwords for validation if passwords dont exist in params" do
        controller.instance_variable_set(:@_params,
                                         :default_userid     => default_creds[:userid],
                                         :amqp_userid        => amqp_creds[:userid],
                                         :ssh_keypair_userid => ssh_keypair_creds[:userid])
        expect(@ems).to receive(:authentication_password).and_return(default_creds[:password])
        expect(@ems).to receive(:authentication_password).with(:amqp).and_return(amqp_creds[:password])
        expect(@ems).to receive(:supports_authentication?).with(:amqp).and_return(true)
        expect(@ems).to receive(:authentication_key).with(:ssh_keypair).and_return(ssh_keypair_creds[:auth_key])
        expect(@ems).to receive(:supports_authentication?).with(:ssh_keypair).and_return(true)
        expect(@ems).to receive(:supports_authentication?).with(:oauth)
        expect(@ems).to receive(:supports_authentication?).with(:auth_key)
        expect(controller.send(:build_credentials, @ems)).to eq(:default     => default_creds,
                                                                :amqp        => amqp_creds,
                                                                :ssh_keypair => ssh_keypair_creds)
      end
    end
  end

  describe "SCVMM - create, update, validate, cancel" do
    before do
      allow(controller).to receive(:check_privileges).and_return(true)
      allow(controller).to receive(:assert_privileges).and_return(true)
      login_as FactoryGirl.create(:user, :features => "ems_infra_new")
    end

    render_views

    it 'creates on post' do
      expect do
        post :create, :params => {
            "button"                    => "add",
            "name"                      => "foo",
            "emstype"                   => "scvmm",
            "zone"                      => zone.name,
            "cred_type"                 => "default",
            "default_hostname"          => "foo.com",
            "default_security_protocol" => "ssl",
            "default_userid"            => "foo",
            "default_password"          => "[FILTERED]",
            "default_verify"            => "[FILTERED]"
        }
      end.to change { ManageIQ::Providers::Microsoft::InfraManager.count }.by(1)
    end

    it 'creates and updates an authentication record on post' do
      expect do
        post :create, :params => {
            "button"                    => "add",
            "name"                      => "foo_scvmm",
            "emstype"                   => "scvmm",
            "zone"                      => zone.name,
            "cred_type"                 => "default",
            "default_hostname"          => "foo.com",
            "default_security_protocol" => "ssl",
            "default_userid"            => "foo",
            "default_password"          => "[FILTERED]",
            "default_verify"            => "[FILTERED]"
        }
      end.to change { Authentication.count }.by(1)

      expect(response.status).to eq(200)
      scvmm = ManageIQ::Providers::Microsoft::InfraManager.where(:name => "foo_scvmm").first
      expect(scvmm.authentications.size).to eq(1)

      expect do
        post :update, :params => {
            "id"               => scvmm.id,
            "button"           => "save",
            "default_hostname" => "host_scvmm_updated",
            "name"             => "foo_scvmm",
            "emstype"          => "scvmm",
            "default_userid"   => "bar",
            "default_password" => "[FILTERED]",
            "default_verify"   => "[FILTERED]"
        }
      end.not_to change { Authentication.count }

      expect(response.status).to eq(200)
      expect(scvmm.authentications.first).to have_attributes(:userid => "bar", :password => "[FILTERED]")
    end

    it "validates credentials for a new record" do
      post :create, :params => {
          "button"           => "validate",
          "cred_type"        => "default",
          "name"             => "foo_scvmm",
          "emstype"          => "scvmm",
          "zone"             => zone.name,
          "default_userid"   => "foo",
          "default_password" => "[FILTERED]",
          "default_verify"   => "[FILTERED]"
      }

      expect(response.status).to eq(200)
    end

    it "cancels a new record" do
      post :create, :params => {
          "button"           => "cancel",
          "cred_type"        => "default",
          "name"             => "foo_scvmm",
          "emstype"          => "scvmm",
          "zone"             => zone.name,
          "default_userid"   => "foo",
          "default_password" => "[FILTERED]",
          "default_verify"   => "[FILTERED]"
      }

      expect(response.status).to eq(200)
    end
  end

  describe "Openstack - create, update" do
    before do
      allow(controller).to receive(:check_privileges).and_return(true)
      allow(controller).to receive(:assert_privileges).and_return(true)
      login_as FactoryGirl.create(:user, :features => "ems_infra_new")
    end

    render_views

    it 'creates on post' do
      expect do
        post :create, :params => {
            "button"                        => "add",
            "name"                          => "foo",
            "emstype"                       => "openstack_infra",
            "zone"                          => zone.name,
            "cred_type"                     => "default",
            "default_hostname"              => "foo.com",
            "default_api_port"              => "5000",
            "default_security_protocol"     => "ssl",
            "default_userid"                => "foo",
            "default_password"              => "[FILTERED]",
            "default_verify"                => "[FILTERED]",
            "amqp_hostname"                 => "foo_amqp.com",
            "amqp_api_port"                 => "5672",
            "amqp_security_protocol"        => "ssl",
            "amqp_userid"                   => "amqp_foo",
            "amqp_password"                 => "[FILTERED]",
            "amqp_verify"                   => "[FILTERED]",
            "ssh_keypair_hostname"          => "foo_ssh.com",
            "ssh_keypair_port"              => "5372",
            "ssh_keypair_security_protocol" => "ssl",
            "ssh_keypair_userid"            => "ssh_foo",
            "ssh_keypair_password"          => "[FILTERED]",
            "ssh_keypair_verify"            => "[FILTERED]"
        }
      end.to change { ManageIQ::Providers::Openstack::InfraManager.count }.by(1)
    end

    it 'creates and updates an authentication record on post' do
      expect do
        post :create, :params => {
            "button"                        => "add",
            "name"                          => "foo_openstack",
            "emstype"                       => "openstack_infra",
            "zone"                          => zone.name,
            "cred_type"                     => "default",
            "default_hostname"              => "foo.com",
            "default_api_port"              => "5000",
            "default_security_protocol"     => "ssl",
            "default_userid"                => "foo",
            "default_password"              => "[FILTERED]",
            "default_verify"                => "[FILTERED]",
            "amqp_hostname"                 => "foo_amqp.com",
            "amqp_api_port"                 => "5672",
            "amqp_security_protocol"        => "ssl",
            "amqp_userid"                   => "amqp_foo",
            "amqp_password"                 => "[FILTERED]",
            "amqp_verify"                   => "[FILTERED]",
            "ssh_keypair_hostname"          => "foo_ssh.com",
            "ssh_keypair_port"              => "5372",
            "ssh_keypair_security_protocol" => "ssl",
            "ssh_keypair_userid"            => "ssh_foo",
            "ssh_keypair_password"          => "[FILTERED]",
            "ssh_keypair_verify"            => "[FILTERED]"
        }
      end.to change { Authentication.count }.by(3)

      expect(response.status).to eq(200)
      openstack = ManageIQ::Providers::Openstack::InfraManager.where(:name => "foo_openstack").first
      expect(openstack.authentications.size).to eq(3)

      expect do
        post :update, :params => {
            "id"               => openstack.id,
            "button"           => "save",
            "default_hostname" => "host_openstack_updated",
            "name"             => "foo_openstack",
            "emstype"          => "openstack_infra",
            "default_userid"   => "bar",
            "default_password" => "[FILTERED]",
            "default_verify"   => "[FILTERED]"
        }
      end.not_to change { Authentication.count }

      expect(response.status).to eq(200)
      expect(openstack.authentications.first).to have_attributes(:userid => "bar", :password => "[FILTERED]")
    end
  end

  describe "Redhat - create, update" do
    before do
      allow(controller).to receive(:check_privileges).and_return(true)
      allow(controller).to receive(:assert_privileges).and_return(true)
      login_as FactoryGirl.create(:user, :features => "ems_infra_new")
    end

    render_views

    it 'creates on post' do
      expect do
        post :create, :params => {
            "button"           => "add",
            "name"             => "foo",
            "emstype"          => "rhevm",
            "zone"             => zone.name,
            "cred_type"        => "default",
            "default_hostname" => "foo.com",
            "default_api_port" => "5000",
            "default_userid"   => "foo",
            "default_password" => "[FILTERED]",
            "default_verify"   => "[FILTERED]",
            "metrics_hostname" => "foo_metrics.com",
            "metrics_api_port" => "5672",
            "metrics_userid"   => "metrics_foo",
            "metrics_password" => "[FILTERED]",
            "metrics_verify"   => "[FILTERED]"
        }
      end.to change { ManageIQ::Providers::Redhat::InfraManager.count }.by(1)
    end

    it 'creates and updates an authentication record on post' do
      expect do
        post :create, :params => {
            "button"           => "add",
            "name"             => "foo_rhevm",
            "emstype"          => "rhevm",
            "zone"             => zone.name,
            "cred_type"        => "default",
            "default_hostname" => "foo.com",
            "default_api_port" => "5000",
            "default_userid"   => "foo",
            "default_password" => "[FILTERED]",
            "default_verify"   => "[FILTERED]",
            "metrics_hostname" => "foo_metrics.com",
            "metrics_api_port" => "5672",
            "metrics_userid"   => "metrics_foo",
            "metrics_password" => "[FILTERED]",
            "metrics_verify"   => "[FILTERED]"
        }
      end.to change { Authentication.count }.by(2)

      expect(response.status).to eq(200)
      rhevm = ManageIQ::Providers::Redhat::InfraManager.where(:name => "foo_rhevm").first
      expect(rhevm.authentications.size).to eq(2)

      expect do
        post :update, :params => {
            "id"               => rhevm.id,
            "button"           => "save",
            "default_hostname" => "host_rhevm_updated",
            "name"             => "foo_rhevm",
            "emstype"          => "rhevm",
            "default_userid"   => "bar",
            "default_password" => "[FILTERED]",
            "default_verify"   => "[FILTERED]"
        }
      end.not_to change { Authentication.count }

      expect(response.status).to eq(200)
      expect(rhevm.authentications.first).to have_attributes(:userid => "bar", :password => "[FILTERED]")
    end
  end

  describe "VMWare - create, update" do
    before do
      allow(controller).to receive(:check_privileges).and_return(true)
      allow(controller).to receive(:assert_privileges).and_return(true)
      login_as FactoryGirl.create(:user, :features => "ems_infra_new")
    end

    render_views

    it 'creates on post' do
      expect do
        post :create, :params => {
            "button"           => "add",
            "name"             => "foo",
            "emstype"          => "vmwarews",
            "zone"             => zone.name,
            "cred_type"        => "default",
            "default_hostname" => "foo.com",
            "default_userid"   => "foo",
            "default_password" => "[FILTERED]",
            "default_verify"   => "[FILTERED]"
        }
      end.to change { ManageIQ::Providers::Vmware::InfraManager.count }.by(1)
    end

    it 'creates and updates an authentication record on post' do
      expect do
        post :create, :params => {
            "button"           => "add",
            "name"             => "foo_vmware",
            "emstype"          => "vmwarews",
            "zone"             => zone.name,
            "cred_type"        => "default",
            "default_hostname" => "foo.com",
            "default_userid"   => "foo",
            "default_password" => "[FILTERED]",
            "default_verify"   => "[FILTERED]"
        }
      end.to change { Authentication.count }.by(1)

      expect(response.status).to eq(200)
      vmware = ManageIQ::Providers::Vmware::InfraManager.where(:name => "foo_vmware").first
      expect(vmware.authentications.size).to eq(1)

      expect do
        post :update, :params => {
            "id"               => vmware.id,
            "button"           => "save",
            "default_hostname" => "host_vmware_updated",
            "name"             => "foo_vmware",
            "emstype"          => "vmwarews",
            "default_userid"   => "bar",
            "default_password" => "[FILTERED]",
            "default_verify"   => "[FILTERED]"
        }
      end.not_to change { Authentication.count }

      expect(response.status).to eq(200)
      expect(vmware.authentications.first).to have_attributes(:userid => "bar", :password => "[FILTERED]")
    end
  end
end

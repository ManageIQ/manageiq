describe ApplicationController do
  before do
    EvmSpecHelper.local_miq_server
    login_as FactoryGirl.create(:user, :features => "everything")
    allow(controller).to receive(:role_allows?).and_return(true)
  end

  context "Verify proper methods are called for snapshot" do
    it "Delete All" do
      expect(controller).to receive(:vm_button_operation)
        .with('remove_all_snapshots', 'delete all snapshots', 'vm_common/config')
      controller.send(:vm_snapshot_delete_all)
    end

    it "Delete Selected" do
      expect(controller).to receive(:vm_button_operation).with('remove_snapshot', 'delete snapshot', 'vm_common/config')
      controller.send(:vm_snapshot_delete)
    end
  end

  # some methods should not be accessible through the legacy routes
  # either by being private or through the hide_action mechanism
  it 'should not allow call of hidden/private actions' do
    # dashboard/process_elements
    expect do
      post :process_elements
    end.to raise_error ActionController::UrlGenerationError
  end

  it "should set correct discovery title" do
    res = controller.send(:set_discover_title, "hosts", "host")
    expect(res).to eq("Hosts / Nodes")

    res = controller.send(:set_discover_title, "ems", "ems_infra")
    expect(res).to eq("Infrastructure Providers")

    res = controller.send(:set_discover_title, "ems", "ems_cloud")
    expect(res).to eq("Cloud Providers")
  end

  it "Certain actions should not be allowed for a MiqTemplate record" do
    template = FactoryGirl.create(:template_vmware)
    controller.instance_variable_set(:@_params, :id => template.id)
    actions = [:vm_right_size, :vm_reconfigure]
    actions.each do |action|
      expect(controller).to receive(:render)
      controller.send(action)
      expect(controller.send(:flash_errors?)).to be_truthy
      expect(assigns(:flash_array).first[:message]).to include("does not apply")
    end
  end

  it "Certain actions should be allowed only for a VM record" do
    feature = MiqProductFeature.find_all_by_identifier(["everything"])
    login_as FactoryGirl.create(:user, :features => feature)
    vm = FactoryGirl.create(:vm_vmware)
    controller.instance_variable_set(:@_params, :id => vm.id)
    actions = [:vm_right_size, :vm_reconfigure]
    actions.each do |action|
      expect(controller).to receive(:render)
      controller.send(action)
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end
  end

  context "Verify the reconfigurable flag for VMs" do
    it "Reconfigure VM action should be allowed only for a VM marked as reconfigurable" do
      vm = FactoryGirl.create(:vm_vmware)
      controller.instance_variable_set(:@_params, :id => vm.id)
      record = controller.send(:get_record, "vm")
      action = :vm_reconfigure
      expect(controller).to receive(:render)
      controller.send(action)
      unless record.reconfigurable?
        expect(controller.send(:flash_errors?)).to be_truthy
        expect(assigns(:flash_array).first[:message]).to include("does not apply")
      end
    end
    it "Reconfigure VM action should not be allowed for a VM marked as reconfigurable" do
      vm = FactoryGirl.create(:vm_microsoft)
      controller.instance_variable_set(:@_params, :id => vm.id)
      record = controller.send(:get_record, "vm")
      action = :vm_reconfigure
      expect(controller).to receive(:render)
      controller.send(action)
      unless record.reconfigurable?
        expect(controller.send(:flash_errors?)).to be_truthy
        expect(assigns(:flash_array).first[:message]).to include("does not apply")
      end
    end
  end

  describe "#supports_reconfigure_disks?" do
    let(:vm) { FactoryGirl.create(:vm_redhat) }

    context "when a single is vm selected" do
      let(:supports_reconfigure_disks) { true }
      before(:each) do
        allow(vm).to receive(:supports_reconfigure_disks?).and_return(supports_reconfigure_disks)
        controller.instance_variable_set(:@reconfigitems, [vm])
      end

      context "when vm supports reconfiguring disks" do
        it "enables reconfigure disks" do
          expect(controller.send(:supports_reconfigure_disks?)).to be_truthy
        end
      end
      context "when vm does not supports reconfiguring disks" do
        let(:supports_reconfigure_disks) { false }
        it "disables reconfigure disks" do
          expect(controller.send(:supports_reconfigure_disks?)).to be_falsey
        end
      end
    end

    context "when multiple vms selected" do
      let(:vm1) { FactoryGirl.create(:vm_redhat) }
      it "disables reconfigure disks" do
        controller.instance_variable_set(:@reconfigitems, [vm, vm1])
        expect(controller.send(:supports_reconfigure_disks?)).to be_falsey
      end
    end
  end

  context "#discover" do
    it "checks that keys in @to remain set if there is an error after submit is pressed" do
      from_first = "1"
      from_second = "1"
      from_third = "1"
      controller.instance_variable_set(:@_params,
                                       :from_first                   => from_first,
                                       :from_second                  => from_second,
                                       :from_third                   => from_third,
                                       :from_fourth                  => "1",
                                       :to_fourth                    => "0",
                                       "discover_type_virtualcenter" => "1",
                                       "start"                       => "45"
                                      )
      allow(controller).to receive(:drop_breadcrumb)
      expect(controller).to receive(:render)
      controller.send(:discover)
      to = assigns(:to)
      expect(to[:first]).to eq(from_first)
      expect(to[:second]).to eq(from_second)
      expect(to[:third]).to eq(from_third)
      expect(controller.send(:flash_errors?)).to be_truthy
    end

    it "displays options to select Azure or Amazon cloud" do
      session[:type] = "ems"
      controller.instance_variable_set( :@_params,
                                        :controller             => "ems_cloud"
                                      )
      allow(controller).to receive(:drop_breadcrumb)
      cloud_manager_stub = double('CloudManager',
                                  :supports_discovery? => true,
                                  :ems_type            => 'example',
                                  :description         => 'Example Manager')
      allow(ManageIQ::Providers::CloudManager).to receive(:subclasses).and_return([cloud_manager_stub])
      controller.send(:discover)
      expect(response.status).to eq(200)
      expect(controller.instance_variable_get(:@discover_type)).to include(["Example Manager", "example"])
    end
  end

  context "#process_elements" do
    it "shows passed in display name in flash message" do
      pxe = FactoryGirl.create(:pxe_server)
      allow(MiqServer).to receive(:my_zone).and_return("default")
      controller.send(:process_elements, [pxe.id], PxeServer, 'synchronize_advertised_images_queue', 'Refresh Relationships')
      expect(assigns(:flash_array).first[:message]).to include("Refresh Relationships successfully initiated")
    end

    it "shows task name in flash message when display name is not passed in" do
      pxe = FactoryGirl.create(:pxe_server)
      allow(MiqServer).to receive(:my_zone).and_return("default")
      controller.send(:process_elements, [pxe.id], PxeServer, 'synchronize_advertised_images_queue')
      expect(assigns(:flash_array).first[:message])
        .to include("synchronize_advertised_images_queue successfully initiated")
    end
  end

  context "#identify_record" do
    it "Verify flash error message when passed in ID no longer exists in database" do
      record = controller.send(:identify_record, "1", ExtManagementSystem)
      expect(record).to be_nil
      expect(assigns(:bang).message).to include("Selected Provider no longer exists")
    end

    it "Verify @record is set for passed in ID" do
      ems = FactoryGirl.create(:ext_management_system)
      record = controller.send(:identify_record, ems.id, ExtManagementSystem)
      expect(record).to be_a_kind_of(ExtManagementSystem)
    end
  end

  context "#get_record" do
    it "use passed in db to set class for identify_record call" do
      host = FactoryGirl.create(:host)
      controller.instance_variable_set(:@_params, :id => host.id)
      record = controller.send(:get_record, "host")
      expect(record).to be_a_kind_of(Host)
    end
  end

  describe "#build_ownership_info" do
    let(:child_role)                     { FactoryGirl.create(:miq_user_role, :name => "Role_1") }
    let(:grand_child_tenant_role)        { FactoryGirl.create(:miq_user_role, :name => "Role_2") }
    let(:great_grand_child_tenant_role)  { FactoryGirl.create(:miq_user_role, :name => "Role_3") }

    let(:child_tenant)             { FactoryGirl.create(:tenant) }
    let(:grand_child_tenant)       { FactoryGirl.create(:tenant, :parent => child_tenant) }
    let(:great_grand_child_tenant) { FactoryGirl.create(:tenant, :parent => grand_child_tenant) }

    let(:child_group) do
      FactoryGirl.create(:miq_group, :description => "Child group", :role => child_role, :tenant => child_tenant)
    end

    let(:grand_child_group) do
      FactoryGirl.create(:miq_group, :description => "Grand child group", :role => grand_child_tenant_role,
                                     :tenant => grand_child_tenant)
    end

    let(:great_grand_child_group) do
      FactoryGirl.create(:miq_group, :description => "Great Grand Child group", :role => great_grand_child_tenant_role,
                                     :tenant => great_grand_child_tenant)
    end
    let(:admin_user) { FactoryGirl.create(:user_admin) }

    it "lists all non-tenant groups when (admin user is logged)" do
      @vm_or_template = FactoryGirl.create(:vm_or_template)
      @ownership_items = [@vm_or_template.id]
      login_as(admin_user)
      controller.instance_variable_set(:@_params, :controller => 'vm_or_template')
      controller.instance_variable_set(:@user, nil)

      controller.build_ownership_info(@ownership_items)
      groups = controller.instance_variable_get(:@groups)
      expect(groups.count).to eq(MiqGroup.non_tenant_groups.count)
    end
  end
end

describe HostController do
  context "#show_association" do
    before(:each) do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @host = FactoryGirl.create(:host)
      @guest_application = FactoryGirl.create(:guest_application, :name => "foo", :host_id => @host.id)
      @datastore = FactoryGirl.create(:storage, :name => 'storage_name')
      @datastore.parent = @host
    end

    it "renders show_item" do
      controller.instance_variable_set(:@breadcrumbs, [])
      allow(controller).to receive(:get_view)
      get :guest_applications, :params => { :id => @host.id, :show => @guest_application.id }
      expect(response.status).to eq(200)
      expect(response).to render_template('host/show')
      expect(assigns(:breadcrumbs)).to eq([{:name => "#{@host.name} (Packages)",
                                            :url  => "/host/guest_applications/#{@host.id}?page="},
                                           {:name => "foo",
                                            :url  => "/host/guest_applications/#{@host.id}?show=#{@guest_application.id}"}
                                          ])
    end

    it "shows associated datastores" do
      controller.instance_variable_set(:@breadcrumbs, [])
      get :show, :params => {:id => @host.id, :display => 'storages'}
      expect(response.status).to eq(200)
      expect(response).to render_template('host/show')
      expect(assigns(:breadcrumbs)).to eq([{:name => "#{@host.name} (All Datastores)",
                                            :url => "/host/show/#{@host.id}?display=storages"}])
    end

    it "renders show_details" do
      controller.instance_variable_set(:@breadcrumbs, [])
      allow(controller).to receive(:get_view)
      get :guest_applications, :params => { :id => @host.id }
      expect(response.status).to eq(200)
      expect(response).to render_template('host/show')
      expect(assigns(:breadcrumbs)).to eq([{:name => "#{@host.name} (Packages)",
                                            :url  => "/host/guest_applications/#{@host.id}"}])
    end

    it "plularizes breadcrumb name" do
      expect(controller.send(:breadcrumb_name, nil)).to eq("Hosts")
    end
  end

  context "#process_objects" do
    it "returns array of object ids " do
      vm1 = FactoryGirl.create(:vm_vmware)
      vm2 = FactoryGirl.create(:vm_vmware)
      vm3 = FactoryGirl.create(:vm_vmware)
      vms = [vm1.id, vm2.id, vm3.id]
      controller.send(:process_objects, vms, 'refresh_ems')
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include "Refresh Provider initiated for #{vms.length} VMs"
    end
  end

  context "#process_hosts" do
    it "initiates host destroy" do
      host = FactoryGirl.create(:host)
      allow(controller).to receive(:filter_ids_in_region).and_return([[host], nil])
      allow(MiqServer).to receive(:my_zone).and_return("default")
      controller.send(:process_hosts, [host], 'destroy')
      audit_event = AuditEvent.all.first
      task = MiqQueue.find_by_class_name("Host")
      expect(audit_event['message']).to include "Record delete initiated"
      expect(task.method_name).to eq 'destroy'
    end
  end

  context "#vm_button_operation" do
    it "when the vm_or_template supports scan,  returns true" do
      vm1 =  FactoryGirl.create(:vm_microsoft)
      vm2 =  FactoryGirl.create(:vm_vmware)
      controller.instance_variable_set(:@_params, :miq_grid_checks => "#{vm1.id}, #{vm2.id}")
      controller.send(:vm_button_operation, 'scan', "Smartstate Analysis")
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to include "Smartstate Analysis does not apply to at least one of the selected Virtual Machines"
    end

    it "when the vm_or_template supports scan,  returns true" do
      vm = FactoryGirl.create(:vm_vmware,
                              :ext_management_system => FactoryGirl.create(:ems_openstack_infra),
                              :storage               => FactoryGirl.create(:storage)
                             )
      controller.instance_variable_set(:@_params, :miq_grid_checks => vm.id.to_s)
      expect(controller).to receive(:process_objects)
      controller.send(:vm_button_operation, 'scan', "Smartstate Analysis")
    end
  end
end

describe ServiceController do
  context "#vm_button_operation" do
    before do
      _guid, @miq_server, @zone = EvmSpecHelper.remote_guid_miq_server_zone
      allow(MiqServer).to receive(:my_zone).and_return("default")
      controller.instance_variable_set(:@lastaction, "show_list")
    end

    it "should render flash message when trying to retire a template" do
      controller.request.parameters["controller"] = "vm_or_template"
      vm = FactoryGirl.create(:vm_vmware,
                              :ext_management_system => FactoryGirl.create(:ems_openstack_infra),
                              :storage               => FactoryGirl.create(:storage)
                             )
      template = FactoryGirl.create(:template,
                                    :ext_management_system => FactoryGirl.create(:ems_openstack_infra),
                                    :storage               => FactoryGirl.create(:storage)
                                   )
      controller.instance_variable_set(:@_params, :miq_grid_checks => "#{vm.id}, #{template.id}")
      expect(controller).to receive(:javascript_flash)
      controller.send(:vm_button_operation, 'retire_now', "Retirement")
      expect(response.status).to eq(200)
    end

    it "should continue to retire a vm" do
      controller.request.parameters["controller"] = "vm_or_template"
      vm = FactoryGirl.create(:vm_vmware,
                              :ext_management_system => FactoryGirl.create(:ems_openstack_infra),
                              :storage               => FactoryGirl.create(:storage)
                             )

      controller.instance_variable_set(:@_params, :miq_grid_checks => vm.id.to_s)
      expect(controller).to receive(:show_list)
      controller.send(:vm_button_operation, 'retire_now', "Retirement")
      expect(response.status).to eq(200)
      expect(assigns(:flash_array).first[:message]).to \
        include("Retirement initiated for 1 VM and Instance from the %{product} Database" % {:product => I18n.t('product.name')})
    end

    it "should continue to retire a service and does not render flash message 'xxx does not apply xxx' " do
      controller.request.parameters["controller"] = "service"
      service = FactoryGirl.create(:service)
      template = FactoryGirl.create(:template,
                                    :ext_management_system => FactoryGirl.create(:ems_openstack_infra),
                                    :storage               => FactoryGirl.create(:storage)
                                   )
      service.update_attribute(:id, template.id)
      service.reload
      controller.instance_variable_set(:@_params, :miq_grid_checks => service.id.to_s)
      expect(controller).to receive(:show_list)
      controller.send(:vm_button_operation, 'retire_now', "Retirement")
      expect(response.status).to eq(200)
      expect(assigns(:flash_array).first[:message]).to \
        include("Retirement initiated for 1 Service from the %{product} Database" % {:product => I18n.t('product.name')})
    end
  end
end

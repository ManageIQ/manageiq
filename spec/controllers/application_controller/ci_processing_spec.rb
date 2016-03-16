describe ApplicationController do
  before do
    EvmSpecHelper.local_miq_server
    login_as FactoryGirl.create(:user, :features => "everything")
    allow(controller).to receive(:role_allows).and_return(true)
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
      controller.send(:discover)
      expect(response.status).to eq(200)
      expect(controller.instance_variable_get(:@discover_type)).to include(["Azure", "azure"], ["Amazon", "amazon"])
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

  describe "#ownership_build_screen" do
    before do
      @admin_user = FactoryGirl.create(:user_admin)
      @user = FactoryGirl.create(:user_with_group)
      @vm_or_template = FactoryGirl.create(:vm_or_template)
      @edit = {:ownership_items => [@vm_or_template.id], :klass => VmOrTemplate, :new => {:user => nil}}
    end

    it "lists all groups when (admin user is logged)" do
      login_as(@admin_user)
      controller.instance_variable_set(:@edit, @edit)
      controller.ownership_build_screen
      groups = controller.instance_variable_get(:@groups)
      expect(groups.count).to eq(MiqGroup.count)
    end

    it "lists all users when (admin user is logged)" do
      login_as(@admin_user)
      controller.instance_variable_set(:@edit, @edit)
      controller.ownership_build_screen
      users = controller.instance_variable_get(:@users)
      expect(users.count).to eq(User.all.count)
    end

    it "lists users from current user's groups (non-admin user is logged)" do
      login_as(@user)
      controller.instance_variable_set(:@edit, @edit)
      controller.ownership_build_screen
      users = controller.instance_variable_get(:@users)
      expect(users.count).to eq(1)
    end

    it "lists user's groups (non-admin user is logged)" do
      login_as(@user)
      controller.instance_variable_set(:@edit, @edit)
      controller.ownership_build_screen
      groups = controller.instance_variable_get(:@groups)
      expect(groups.count).to eq(1)
    end
  end
end

describe HostController do
  context "#show_association" do
    before(:each) do
      set_user_privileges
      EvmSpecHelper.create_guid_miq_server_zone
      @host = FactoryGirl.create(:host)
      @guest_application = FactoryGirl.create(:guest_application, :name => "foo", :host_id => @host.id)
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
      controller.instance_variable_set(:@_params, :miq_grid_checks => "#{vm.id}")
      expect(controller).to receive(:process_objects)
      controller.send(:vm_button_operation, 'scan', "Smartstate Analysis")
    end
  end
end

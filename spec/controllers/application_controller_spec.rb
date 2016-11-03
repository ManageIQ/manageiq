require 'ostruct'

describe ApplicationController do
  example ".model" do
    expect(CimStorageExtentController.model).to eq CimStorageExtent
  end

  context "#find_by_id_filtered" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      controller.instance_variable_set(:@sb, {})
      ur = FactoryGirl.create(:miq_user_role)
      rptmenu = {:report_menus => [["Configuration Management", ["Hosts", ["Hosts Summary", "Hosts Summary"]]]]}
      group = FactoryGirl.create(:miq_group, :miq_user_role => ur, :settings => rptmenu)
      login_as FactoryGirl.create(:user, :miq_groups => [group])
    end

    it "Verify Invalid input flash error message when invalid id is passed in" do
      expect { controller.send(:find_by_id_filtered, ExtManagementSystem, "invalid") }.to raise_error(RuntimeError, "Invalid input")
    end

    it "Verify flash error message when passed in id no longer exists in database" do
      expect { controller.send(:find_by_id_filtered, ExtManagementSystem, "1") }.to raise_error(RuntimeError, "Selected Provider no longer exists")
    end

    it "Verify record gets set when valid id is passed in" do
      ems = FactoryGirl.create(:ext_management_system)
      expect(controller.send(:find_by_id_filtered, ExtManagementSystem, ems.id)).to eq(ems)
    end
  end

  context "#assert_privileges" do
    before do
      EvmSpecHelper.seed_specific_product_features("host_new", "host_edit", "perf_reload")
      feature = MiqProductFeature.find_all_by_identifier(["host_new"])
      login_as FactoryGirl.create(:user, :features => feature)
    end

    it "should not raise an error for feature that user has access to" do
      expect { controller.send(:assert_privileges, "host_new") }.not_to raise_error
    end

    it "should raise an error for feature that user does not have access to" do
      msg = "The user is not authorized for this task or item."
      expect { controller.send(:assert_privileges, "host_edit") }.to raise_error(MiqException::RbacPrivilegeException, msg)
    end

    it "should not raise an error for common hidden feature under a hidden parent" do
      expect { controller.send(:assert_privileges, "perf_reload") }.not_to raise_error
    end
  end

  context "#previous_breadcrumb_url" do
    it "should return url when 2 entries" do
      controller.instance_variable_set(:@breadcrumbs, [{:url => "test_url"}, 'placeholder'])
      expect(controller.send(:previous_breadcrumb_url)).to eq("test_url")
    end

    it "should raise for less than 2 entries" do
      controller.instance_variable_set(:@breadcrumbs, [{}])
      expect { controller.send(:previous_breadcrumb_url) }.to raise_error(NoMethodError)

      controller.instance_variable_set(:@breadcrumbs, [])
      expect { controller.send(:previous_breadcrumb_url) }.to raise_error(NoMethodError)
    end
  end

  context "#find_checked_items" do
    it "returns empty array when button is pressed from summary screen with params as symbol" do
      controller.instance_variable_set(:@_params, :id => "1")
      expect(controller.send(:find_checked_items)).to eq([])
    end

    it "returns empty array when button is pressed from summary screen with params as string" do
      controller.instance_variable_set(:@_params, "id" => "1")
      expect(controller.send(:find_checked_items)).to eq([])
    end

    it "returns list of items selected from list view" do
      controller.instance_variable_set(:@_params, :miq_grid_checks => "1, 2, 3, 4")
      expect(controller.send(:find_checked_items)).to eq([1, 2, 3, 4])
    end
  end

  context "#render_gtl_view_tb?" do
    before do
      controller.instance_variable_set(:@layout, "host")
      controller.instance_variable_set(:@gtl_type, "list")
    end

    it "returns true for list views" do
      controller.instance_variable_set(:@_params, :action => "show_list")
      expect(controller.send(:render_gtl_view_tb?)).to be_truthy
    end

    it "returns true for list views when navigating thru relationships" do
      controller.instance_variable_set(:@_params, :action => "show")
      expect(controller.send(:render_gtl_view_tb?)).to be_truthy
    end

    it "returns false for sub list views" do
      controller.instance_variable_set(:@_params, :action => "host_services")
      expect(controller.send(:render_gtl_view_tb?)).to be_falsey
    end
  end

  context "#set_config" do
    it "sets Processors details successfully" do
      host_hardware = FactoryGirl.create(:hardware, :cpu_sockets => 2, :cpu_cores_per_socket => 4, :cpu_total_cores => 8)
      host = FactoryGirl.create(:host, :hardware => host_hardware)
      stub_user(:features => :all)

      controller.send(:set_config, host)
      expect(response.status).to eq(200)
      expect(assigns(:devices)).to_not be_empty
    end

    it "doesn't crash on nil filename" do
      disk = FactoryGirl.create(:disk, :filename => nil, :controller_type => nil, :device_type => 'disk', :mode => "foo")
      host_hardware = FactoryGirl.create(:hardware, :cpu_sockets => 2, :cpu_cores_per_socket => 4, :cpu_total_cores => 8, :disks => [disk])
      host = FactoryGirl.create(:host, :hardware => host_hardware)
      stub_user(:features => :all)

      controller.send(:set_config, host)
      expect(response.status).to eq(200)
      expect(assigns(:devices)).to_not be_empty
    end

    it "doesn't crash on one letter controller_type" do
      disk = FactoryGirl.create(:disk, :controller_type => nil)
      host_hardware = FactoryGirl.create(:hardware, :cpu_sockets => 2, :cpu_cores_per_socket => 4, :cpu_total_cores => 8, :disks => [disk])
      host = FactoryGirl.create(:host, :hardware => host_hardware)
      stub_user(:features => :all)

      controller.send(:set_config, host)
      expect(response.status).to eq(200)
      expect(assigns(:devices)).to_not be_empty
    end
  end

  context "#prov_redirect" do
    before do
      login_as FactoryGirl.create(:user, :features => "vm_migrate")
      controller.request.parameters[:pressed] = "vm_migrate"
    end

    it "returns flash message when Migrate button is pressed with list containing SCVMM VM" do
      vm1 = FactoryGirl.create(:vm_vmware)
      vm2 = FactoryGirl.create(:vm_microsoft)
      controller.instance_variable_set(:@_params, :pressed         => "vm_migrate",
                                                  :miq_grid_checks => "#{vm1.id},#{vm2.id}")
      controller.set_response!(response)
      controller.send(:prov_redirect, "migrate")
      expect(assigns(:flash_array).first[:message]).to include("does not apply to at least one of the selected")
    end

    let(:ems)     { FactoryGirl.create(:ext_management_system) }
    let(:storage) { FactoryGirl.create(:storage) }

    it "sets variables when Migrate button is pressed with list of VMware VMs" do
      vm1 = FactoryGirl.create(:vm_vmware, :storage => storage, :ext_management_system => ems)
      vm2 = FactoryGirl.create(:vm_vmware, :storage => storage, :ext_management_system => ems)
      controller.instance_variable_set(:@_params, :pressed         => "vm_migrate",
                                                  :miq_grid_checks => "#{vm1.id},#{vm2.id}")
      controller.set_response!(response)
      controller.send(:prov_redirect, "migrate")
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(assigns(:org_controller)).to eq("vm")
    end
  end

  context "#prov_redirect" do
    before do
      login_as FactoryGirl.create(:user, :features => "image_miq_request_new")
      allow(User).to receive(:server_timezone).and_return("UTC")
      controller.request.parameters[:pressed] = "image_miq_request_new"
      controller.instance_variable_set(:@explorer, true)
    end

    it "returns flash message when Provisioning button is pressed from list and selected Image is archived" do
      template = FactoryGirl.create(:miq_template,
                                    :name     => "template 1",
                                    :vendor   => "vmware",
                                    :location => "template1.vmtx")
      controller.instance_variable_set(:@_params,
                                       :pressed         => "image_miq_request_new",
                                       :miq_grid_checks => template.id.to_s)
      controller.set_response!(response)
      expect(controller).not_to receive(:vm_pre_prov)
      controller.send(:prov_redirect)
      expect(assigns(:flash_array).first[:message]).to include("does not apply to at least one of the selected")
    end

    let(:ems)     { FactoryGirl.create(:ems_openstack) }
    let(:storage) { FactoryGirl.create(:storage) }

    it "sets provisioning data and skips pre provisioning dialog" do
      template = FactoryGirl.create(:template_openstack,
                                    :name                  => "template 1",
                                    :vendor                => "vmware",
                                    :location              => "template1.vmtx",
                                    :ext_management_system => ems)
      controller.instance_variable_set(:@_params,
                                       :pressed         => "image_miq_request_new",
                                       :miq_grid_checks => template.id.to_s)
      controller.instance_variable_set(:@breadcrumbs, [])
      controller.instance_variable_set(:@sb, {})
      controller.set_response!(response)
      expect(controller).to receive(:vm_pre_prov)
      expect(controller).not_to receive(:build_vm_grid)
      allow(controller).to receive(:replace_right_cell)
      controller.send(:prov_redirect)
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(assigns(:org_controller)).to eq("vm")
    end
  end

  context "#determine_record_id_for_presenter" do
    context "when in a form" do
      before do
        controller.instance_variable_set(:@in_a_form, true)
      end

      it "return nil when @edit is nil" do
        controller.instance_variable_set(:@edit, nil)
        expect(controller.send(:determine_record_id_for_presenter)).to be_nil
      end

      it "returns @edit[:rec_id] when @edit is not nil" do
        [nil, 42].each do |id|
          edit = {:rec_id => id}
          controller.instance_variable_set(:@edit, edit)
          expect(controller.send(:determine_record_id_for_presenter)).to eq(id)
        end
      end
    end

    context "when not in a form" do
      before do
        controller.instance_variable_set(:@in_a_form, false)
      end

      it "returns nil when @record is nil" do
        controller.instance_variable_set(:@record, nil)
        expect(controller.send(:determine_record_id_for_presenter)).to be_nil
      end

      it "returns @record.id when @record is not nil" do
        [nil, 42].each do |id|
          record = double("Record")
          allow(record).to receive(:id).and_return(id)
          controller.instance_variable_set(:@record, record)
          expect(controller.send(:determine_record_id_for_presenter)).to eq(id)
        end
      end
    end

    context "#get_view" do
      it 'calculates grid hash condition' do
        controller.instance_variable_set(:@force_no_grid_xml, false)
        controller.instance_variable_set(:@force_grid_xml, true)
        controller.instance_variable_set(:@gtl_type, "list")

        view = OpenStruct.new
        view.db = "MiqProvision"
        expect(controller.send(:grid_hash_conditions, view)).to eq(false)
        view.db = "Build"
        expect(controller.send(:grid_hash_conditions, view)).to eq(false)
        view.db = "ContainerBuild"
        expect(controller.send(:grid_hash_conditions, view)).to eq(true)
        controller.instance_variable_set(:@force_no_grid_xml, true)
        expect(controller.send(:grid_hash_conditions, view)).to eq(false)
      end
    end
  end

  describe "#build_user_emails_for_edit" do
    before :each do
      EvmSpecHelper.local_miq_server
      MiqUserRole.seed

      role = MiqUserRole.find_by_name("EvmRole-operator")

      group1 = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Group1")
      @user1 = FactoryGirl.create(:user, :userid => "User1", :miq_groups => [group1], :email => "user1@test.com")

      group2 = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Group2")
      @user2 = FactoryGirl.create(:user, :userid => "User2", :miq_groups => [group2], :email => "user2@test.com")

      current_group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Current Group")
      @current_user = FactoryGirl.create(:user, :userid => "Current User", :miq_groups => [current_group, group1],
                                                :email => "current_user@test.com")

      login_as @current_user

      @edit = {:new => {:email => {:to => []}}, :user_emails => []}
    end

    it "finds users with groups which belongs to current user's groups" do
      user_ids = User.with_current_user_groups.collect(&:userid)
      expect(user_ids).to include(@current_user.userid)
      expect(user_ids).to include(@user1.userid)
    end

    it "listing users's emails which belongs to current user's groups" do
      controller.instance_variable_set(:@edit, @edit)

      expect do
        controller.send(:build_user_emails_for_edit)
        @edit = controller.instance_variable_get(:@edit)
      end.to change { @edit[:user_emails].count }.from(0).to(2)

      @edit = controller.instance_variable_get(:@edit)

      expect(@edit[:user_emails]).not_to be_blank
      expect(@edit[:user_emails]).to include(@current_user.email => "#{@current_user.name} (#{@current_user.email})")
      expect(@edit[:user_emails]).to include(@user1.email => "#{@user1.name} (#{@user1.email})")
      expect(@edit[:user_emails]).not_to include(@user2.email => "#{@user2.name} (#{@user2.email})")
    end

    it "listing users's emails which belongs to current user's groups and some of them was already selected" do
      @edit[:new][:email][:to] = [@current_user.email] # selected users

      controller.instance_variable_set(:@edit, @edit)

      expect do
        controller.send(:build_user_emails_for_edit)
        @edit = controller.instance_variable_get(:@edit)
      end.to change { @edit[:user_emails].count }.from(0).to(1)

      expect(@edit[:user_emails]).not_to be_blank
      current_user_hash = {@current_user.email => "#{@current_user.name} (#{@current_user.email})"}
      expect(@edit[:user_emails]).not_to include(current_user_hash)
      expect(@edit[:user_emails]).to include(@user1.email => "#{@user1.name} (#{@user1.email})")
    end
  end

  describe "#replace_trees_by_presenter" do
    let(:tree_1) { double(:name => 'tree_1') }
    let(:tree_2) { double(:name => 'tree_2') }
    let(:trees) { {'tree_1' => tree_1, 'tree_2' => tree_2, 'tree_3' => nil} }
    let(:presenter) { double(:presenter) }

    it "calls render and passes data to presenter for each pair w/ value" do
      expect(controller).to receive(:render_to_string).with(any_args).twice
      expect(presenter).to receive(:replace).with(any_args).twice
      controller.send(:replace_trees_by_presenter, presenter, trees)
    end
  end
end

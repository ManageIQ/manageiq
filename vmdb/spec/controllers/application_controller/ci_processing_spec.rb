require "spec_helper"
include UiConstants

describe ApplicationController do
  before do
    feature = MiqProductFeature.find_all_by_identifier(["everything"])
    test_user_role  = FactoryGirl.create(:miq_user_role,
                                         :name                 => "test_user_role",
                                         :miq_product_features => feature)
    test_user_group = FactoryGirl.create(:miq_group, :miq_user_role => test_user_role)
    user = FactoryGirl.create(:user, :userid => 'test_user', :miq_groups => [test_user_group])
    User.stub(:current_user => user)
    controller.stub(:role_allows).and_return(true)
  end

  context "Verify proper methods are called for snapshot" do
    it "Delete All" do
      controller.should_receive(:vm_button_operation).with('remove_all_snapshots', 'delete all snapshots', 'vm_common/config')
      controller.send(:vm_snapshot_delete_all)
    end

    it "Delete Selected" do
      controller.should_receive(:vm_button_operation).with('remove_snapshot', 'delete snapshot', 'vm_common/config')
      controller.send(:vm_snapshot_delete)
    end
  end

  # some methods should not be accessible through the legacy routes
  # either by being private or through the hide_action mechanism
  it 'should not allow call of hidden/private actions' do
    # dashboard/process_elements
    expect {
      post :process_elements
    }.to raise_error ActionController::RoutingError
  end

  it "should set correct discovery title" do
    res = controller.send(:set_discover_title,"host", "host")
    res.should == "Hosts"

    res = controller.send(:set_discover_title,"ems", "ems_infra")
    res.should == "Infrastructure Providers"

    res = controller.send(:set_discover_title,"ems", "ems_cloud")
    res.should == "Amazon Cloud Providers"
  end

  it "Certain actions should not be allowed for a MiqTemplate record" do
    template = FactoryGirl.create(:template_vmware)
    controller.instance_variable_set(:@_params, :id => template.id)
    actions = [:vm_right_size, :vm_reconfigure]
    actions.each do |action|
      controller.should_receive(:render)
      controller.send(action)
      controller.send(:flash_errors?).should be_true
      assigns(:flash_array).first[:message].should include("does not apply")
    end
  end

  it "Certain actions should be allowed only for a VM record" do
    admin_role  = FactoryGirl.create(:miq_user_role, :name => "admin", :miq_product_features => MiqProductFeature.find_all_by_identifier(["everything"]))
    admin_group = FactoryGirl.create(:miq_group, :miq_user_role => admin_role)
    user        = FactoryGirl.create(:user, :userid => 'wilma', :miq_groups => [admin_group])
    User.stub(:current_user => user)
    vm = FactoryGirl.create(:vm_vmware)
    controller.instance_variable_set(:@_params, :id => vm.id)
    actions = [:vm_right_size, :vm_reconfigure]
    actions.each do |action|
      controller.should_receive(:render)
      controller.send(action)
      controller.send(:flash_errors?).should_not be_true
    end
  end

  context "Verify memory format for reconfiguring VMs" do
    it "set_memory_cpu should set old values to default when both vms have differnt memory/cpu values" do
      vm1 = FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :memory_cpu => 1024, :logical_cpus => 1))
      vm2 = FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :memory_cpu => 512, :logical_cpus => 2))
      edit = Hash.new
      edit[:new] = Hash.new
      controller.instance_variable_set(:@reconfigureitems, [vm1, vm2])
      controller.instance_variable_set(:@edit, edit)
      controller.send(:set_memory_cpu)
      edit_new = assigns(:edit)[:new]
      edit_new[:old_memory].should == ""
      edit_new[:old_mem_typ].should == "MB"
      edit_new[:old_cpu_count] == 1
    end

    it "set_memory_cpu should use vms value to set old values when both vms have same memory/cpu values" do
      vm1 = FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :memory_cpu => 2048, :logical_cpus => 2))
      vm2 = FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware, :memory_cpu => 2048, :logical_cpus => 2))
      edit = Hash.new
      edit[:new] = Hash.new
      controller.instance_variable_set(:@reconfigureitems, [vm1, vm2])
      controller.instance_variable_set(:@edit, edit)
      controller.send(:set_memory_cpu)
      edit_new = assigns(:edit)[:new]
      edit_new[:old_memory].should == "2"
      edit_new[:old_mem_typ].should == "GB"
      edit_new[:old_cpu_count] == 2
    end

    it "check reconfigure_calculations returns memory in string format" do
      memory, format = controller.send(:reconfigure_calculations, 1024)
      memory.should be_a_kind_of(String)
    end

    it "VM reconfigure memory validation should not show value must be integer error" do
      vm = FactoryGirl.create(:vm_vmware)
      edit = Hash.new
      edit[:key] = "reconfigure__new"
      edit[:new] = Hash.new
      edit[:new][:memory] = "4"
      edit[:new][:mem_typ] = "MB"
      edit[:new][:cb_memory] = true
      edit[:errors] = []
      controller.instance_variable_set(:@edit, edit)
      session[:edit] = edit
      controller.instance_variable_set(:@_params, {:button => "submit"})
      controller.instance_variable_set(:@breadcrumbs, ["test",{:url => "test/show"}])
      controller.should_receive(:render)
      VmReconfigureRequest.stub(:create_request)
      controller.send(:reconfigure_update)
      controller.send(:flash_errors?).should_not be_true
    end
  end

  context "#discover" do
    it "checks that keys in @to remain set if there is an error after submit is pressed" do
      from_first = "1"
      from_second = "1"
      from_third = "1"
      controller.instance_variable_set(:@_params,
                                            :from_first => from_first,
                                            :from_second => from_second,
                                            :from_third => from_third,
                                            :from_fourth => "1",
                                            :to_fourth => "0",
                                            "discover_type_virtualcenter" => "1",
                                            "start.x" => "45"
                                      )
      controller.stub(:drop_breadcrumb)
      controller.should_receive(:render)
      controller.send(:discover)
      to = assigns(:to)
      to[:first].should == from_first
      to[:second].should == from_second
      to[:third].should == from_third
      controller.send(:flash_errors?).should be_true
    end
  end

  context "#process_elements" do
    it "shows passed in display name in flash message" do
      pxe = FactoryGirl.create(:pxe_server)
      MiqServer.stub(:my_zone).and_return("default")
      controller.send(:process_elements, [pxe.id], PxeServer, 'synchronize_advertised_images_queue', 'Refresh Relationships')
      assigns(:flash_array).first[:message].should include("Refresh Relationships successfully initiated")
    end

    it "shows task name in flash message when display name is not passed in" do
      pxe = FactoryGirl.create(:pxe_server)
      MiqServer.stub(:my_zone).and_return("default")
      controller.send(:process_elements, [pxe.id], PxeServer, 'synchronize_advertised_images_queue')
      assigns(:flash_array).first[:message].should include("synchronize_advertised_images_queue successfully initiated")
    end
  end

  context "#identify_record" do
    it "Verify flash error message when passed in ID no longer exists in database" do
      record = controller.send(:identify_record, "1", ExtManagementSystem)
      record.should == nil
      assigns(:bang).message.should include("Selected Provider no longer exists")
    end

    it "Verify @record is set for passed in ID" do
      ems = FactoryGirl.create(:ext_management_system)
      record = controller.send(:identify_record, ems.id, ExtManagementSystem)
      record.should be_a_kind_of(ExtManagementSystem)
    end
  end

  context "#get_record" do
    it "use passed in db to set class for identify_record call" do
      host = FactoryGirl.create(:host)
      controller.instance_variable_set(:@_params, {:id => host.id})
      record = controller.send(:get_record, "host")
      record.should be_a_kind_of(Host)
    end
  end
end

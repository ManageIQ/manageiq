require "spec_helper"

describe VmInfraController do
  before(:each) do
    set_user_privileges

    session[:settings] = {:quadicons => nil, :views => {:treesize => 20}   }

    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone
  end

  render_views

  it 'can render the explorer' do
    session[:settings] = {:views => {}, :perpage => {:list => 10}}

    expect(MiqServer.my_server).to be
    get :explorer
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end

  # http://localhost:3000/vm_infra/show/10000000001403?display=vmtree_info
  it 'can render the genealogy tree' do
    vm = FactoryGirl.create(:vm_vmware)
    seed_session_trees('vm_infra', 'vms_instances_filter_tree')
    xhr :post, :show, :id => vm.id, :display => 'vmtree_info'
    expect(response.status).to eq(200)
    response.should render_template('vm_common/_vmtree')
  end

  # http://localhost:3000/vm_infra/show/10000000000449
  it 'can open a VM and select it in the left tree' do
    vm = FactoryGirl.create(:vm_vmware, :name => 'gabelstaplerfahrer')

    get :show, :id => vm.id
    response.should redirect_to(:action => 'explorer')

    post :explorer
    node_id = "v-#{vm.compressed_id}"
    expect(response.body).to match(/miqDynatreeActivateNodeSilently\('vandt_tree', '#{node_id}'\);/)

    response.should render_template('shared/summary/_textual_tags')
    expect(response.body).to match(/VM and Instance &quot;#{vm.name}&quot;/)

    expect(response.status).to eq(200)
  end

  it 'can open the right size tab' do
    vm = FactoryGirl.create(:vm_vmware, :name => 'a_name')

    get :show, :id => vm.id
    response.should redirect_to(:action => 'explorer')

    post :explorer
    expect(response.status).to eq(200)

    post :x_button, :pressed => 'vm_right_size', :id => vm.id
    expect(response.status).to eq(200)
  end

  it 'can open the reconfigure tab' do
    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone

    host = FactoryGirl.create(:host, :vmm_vendor => 'vmware', :vmm_product => "ESX", :hardware => FactoryGirl.create(:hardware, :memory_cpu => 1024, :logical_cpus => 1))
    vm = FactoryGirl.create(:vm_vmware, :name => 'b_name', :host => host, :hardware => FactoryGirl.create(:hardware, :memory_cpu => 1024, :logical_cpus => 1, :virtual_hw_version => '04'))
    controller.stub(:x_node).and_return("v-#{vm.compressed_id}")

    get :show, :id => vm.id
    response.should redirect_to(:action => 'explorer')

    post :explorer
    expect(response.status).to eq(200)

    post :x_button, :pressed => 'vm_reconfigure', :id => vm.id
    expect(response.status).to eq(200)
  end

  it 'the reconfigure tab for a vm with max_cores_per_socket <= 1 should not display the cores_per_socket dropdown' do
    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone

    host = FactoryGirl.create(:host, :vmm_vendor => 'vmware', :vmm_product => "ESX", :hardware => FactoryGirl.create(:hardware, :memory_cpu => 1024, :logical_cpus => 1))
    vm = FactoryGirl.create(:vm_vmware, :name => 'b_name', :host => host, :hardware => FactoryGirl.create(:hardware, :memory_cpu => 1024, :logical_cpus => 1, :virtual_hw_version => "04"))
    controller.stub(:x_node).and_return("v-#{vm.compressed_id}")

    get :show, :id => vm.id
    response.should redirect_to(:action => 'explorer')

    post :explorer
    expect(response.status).to eq(200)

    post :x_button, :pressed => 'vm_reconfigure', :id => vm.id
    expect(response.status).to eq(200)
    expect(response.body).to_not include('Total Processors')
  end

  it 'the reconfigure tab for a vm with max_cores_per_socket > 1 should display the cores_per_socket dropdown' do
    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone

    host = FactoryGirl.create(:host, :vmm_vendor => 'vmware', :vmm_product => "ESX", :hardware => FactoryGirl.create(:hardware, :memory_cpu => 1024, :logical_cpus => 4))
    vm = FactoryGirl.create(:vm_vmware, :name => 'b_name', :host => host, :hardware => FactoryGirl.create(:hardware, :memory_cpu => 1024, :logical_cpus => 1, :virtual_hw_version => "07"))
    controller.stub(:x_node).and_return("v-#{vm.compressed_id}")

    get :show, :id => vm.id
    response.should redirect_to(:action => 'explorer')

    post :explorer
    expect(response.status).to eq(200)

    post :x_button, :pressed => 'vm_reconfigure', :id => vm.id
    expect(response.status).to eq(200)
    expect(response.body).to include('Total Processors')
  end

  context "skip or drop breadcrumb" do
    before do
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      FactoryGirl.create(:vmdb_database)
      @vm = VmInfra.create(:name => "testvm", :location => "testvm_location", :vendor => "vmware")
      get :explorer
      request.env['HTTP_REFERER'] = request.fullpath
    end

    it 'skips dropping a breadcrumb when a button action is executed' do
      post :x_button, :id => @vm.id, :pressed => 'vm_ownership'
      breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
      expect(breadcrumbs.size).to eq(1)
      expect(breadcrumbs).to include(:name => "VM or Templates", :url => "/vm_infra/explorer")
    end

    it 'drops a breadcrumb when an action allowing breadcrumbs is executed' do
      post :accordion_select, :id => "vms_filter"
      breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
      expect(breadcrumbs.size).to eq(1)
      expect(breadcrumbs).to include(:name => "Virtual Machines", :url => "/vm_infra/explorer")
    end
  end

  context "clear or retain existing breadcrumb path" do
    before do
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      FactoryGirl.create(:vmdb_database)
      @vm = VmInfra.create(:name => "testvm", :location => "testvm_location", :vendor => "vmware")
      controller.stub(:render)
      controller.stub(:build_toolbar_buttons_and_xml)
    end

    it 'it clears the existing breadcrumb path and assigns the new explorer path when controllers are switched' do
      breadcrumbs = []
      breadcrumbs[0] = {:name => "Instances", :url => "/vm_cloud/explorer"}
      session[:breadcrumbs] = breadcrumbs
      controller.stub(:x_node).and_return("v-#{@vm.compressed_id}")
      controller.stub(:controller_referrer?).and_return(false)
      get :explorer
      breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
      expect(breadcrumbs.size).to eq(1)
      expect(breadcrumbs).to include(:name => "VM or Templates", :url => "/vm_infra/explorer")
    end

    it 'retains the breadcrumb path when cancel is pressed from a VM action' do
      get :explorer
      controller.stub(:controller_referrer?).and_return(true)
      controller.stub(:x_node).and_return("v-#{@vm.compressed_id}")
      post :x_button, :id => @vm.id, :pressed => 'vm_ownership'

      controller.instance_variable_set(:@in_a_form, nil)
      post :ownership_update, :button => 'cancel'

      breadcrumbs = controller.instance_variable_get(:@breadcrumbs)
      expect(breadcrumbs.size).to eq(1)
      expect(breadcrumbs).to include(:name => "VM or Templates", :url => "/vm_infra/explorer")
    end
  end
end

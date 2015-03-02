require "spec_helper"

describe VmInfraController do
  before(:each) do
    set_user_privileges

    session[:userid] = User.current_user.userid
    session[:eligible_groups] = []
    session[:settings] = {:quadicons => nil}

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

  context "skip or drop breadcrumb" do
    before do
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      session[:userid] = User.current_user.userid
      session[:eligible_groups] = []
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
end

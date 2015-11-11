require "spec_helper"

describe VmInfraController do
  let(:host_1x1)  { FactoryGirl.create(:host_vmware_esx, :hardware => FactoryGirl.create(:hardware, :cpu1x1, :ram1GB)) }
  let(:host_2x2)  { FactoryGirl.create(:host_vmware_esx, :hardware => FactoryGirl.create(:hardware, :cpu2x2, :ram1GB)) }
  let(:vm_vmware) { FactoryGirl.create(:vm_vmware) }
  before do
    set_user_privileges

    session[:settings] = {:quadicons => nil, :views => {:treesize => 20}}

    EvmSpecHelper.create_guid_miq_server_zone
  end

  render_views

  it 'can render the explorer' do
    session[:settings] = {:views => {}, :perpage => {:list => 10}}

    get :explorer
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end

  # http://localhost:3000/vm_infra/show/10000000001403?display=vmtree_info
  it 'can render the genealogy tree' do
    seed_session_trees('vm_infra', 'vms_instances_filter_tree')
    xhr :post, :show, :id => vm_vmware.id, :display => 'vmtree_info'
    expect(response.status).to eq(200)
    expect(response).to render_template('vm_common/_vmtree')
  end

  # http://localhost:3000/vm_infra/show/10000000000449
  it 'can open a VM and select it in the left tree' do
    get :show, :id => vm_vmware.id
    response.should redirect_to(:action => 'explorer')

    post :explorer
    node_id = "v-#{vm_vmware.compressed_id}"
    expect(response.body).to match(/miqDynatreeActivateNodeSilently\('vandt_tree', '#{node_id}'\);/)

    expect(response).to render_template('shared/summary/_textual_tags')
    expect(response.body).to match(/VM and Instance &quot;#{vm_vmware.name}&quot;/)

    expect(response.status).to eq(200)
  end

  it 'can open the right size tab' do
    get :show, :id => vm_vmware.id
    expect(response).to redirect_to(:action => 'explorer')

    post :explorer
    expect(response.status).to eq(200)

    post :x_button, :pressed => 'vm_right_size', :id => vm_vmware.id
    expect(response.status).to eq(200)
  end

  it 'can open the reconfigure tab' do
    vm = FactoryGirl.create(:vm_vmware, :host => host_1x1, :hardware => FactoryGirl.create(:hardware, :cpu1x1, :ram1GB, :virtual_hw_version => '04'))
    controller.stub(:x_node).and_return("v-#{vm.compressed_id}")

    get :show, :id => vm.id
    expect(response).to redirect_to(:action => 'explorer')

    post :explorer
    expect(response.status).to eq(200)

    post :x_button, :pressed => 'vm_reconfigure', :id => vm.id
    expect(response.status).to eq(200)
  end

  it 'the reconfigure tab for a vm with max_cpu_cores_per_socket <= 1 should not display the cpu_cores_per_socket dropdown' do
    vm = FactoryGirl.create(:vm_vmware, :host => host_1x1, :hardware => FactoryGirl.create(:hardware, :cpu1x1, :ram1GB, :virtual_hw_version => '04'))
    controller.stub(:x_node).and_return("v-#{vm.compressed_id}")

    get :show, :id => vm.id
    expect(response).to redirect_to(:action => 'explorer')

    post :explorer
    expect(response.status).to eq(200)

    post :x_button, :pressed => 'vm_reconfigure', :id => vm.id
    expect(response.status).to eq(200)
    expect(response.body).to_not include('Total Processors')
  end

  it 'the reconfigure tab for a vm with max_cpu_cores_per_socket > 1 should display the cpu_cores_per_socket dropdown' do
    vm = FactoryGirl.create(:vm_vmware, :host => host_2x2, :hardware => FactoryGirl.create(:hardware, :cpu1x1, :ram1GB, :virtual_hw_version => "07"))
    controller.stub(:x_node).and_return("v-#{vm.compressed_id}")

    get :show, :id => vm.id
    expect(response).to redirect_to(:action => 'explorer')

    post :explorer
    expect(response.status).to eq(200)

    post :x_button, :pressed => 'vm_reconfigure', :id => vm.id
    expect(response.status).to eq(200)
    expect(response.body).to include('Total Processors')
  end

  it 'the reconfigure tab displays the submit and cancel buttons' do
    vm = FactoryGirl.create(:vm_vmware, :host => host_2x2, :hardware => FactoryGirl.create(:hardware, :cpu1x1, :ram1GB, :virtual_hw_version => "07"))
    controller.stub(:x_node).and_return("v-#{vm.compressed_id}")

    get :show, :id => vm.id
    expect(response).to redirect_to(:action => 'explorer')

    post :explorer
    expect(response.status).to eq(200)

    post :x_button, :pressed => 'vm_reconfigure', :id => vm.id
    expect(response.status).to eq(200)
    expect(response.body).to include('button=submit')
    expect(response.body).to include('button=cancel')
  end

  context "breadcrumbs" do
    subject { controller.instance_variable_get(:@breadcrumbs) }
    before  { session[:settings] = {:views => {}, :perpage => {:list => 10}} }

    context "skip or drop breadcrumb" do
      before { get :explorer }

      it 'skips dropping a breadcrumb when a button action is executed' do
        post :x_button, :id => vm_vmware.id, :pressed => 'vm_ownership'
        expect(subject).to eq([{:name => "VM or Templates", :url => "/vm_infra/explorer"}])
      end

      it 'drops a breadcrumb when an action allowing breadcrumbs is executed' do
        post :accordion_select, :id => "vms_filter"
        expect(subject).to eq([{:name => "Virtual Machines", :url => "/vm_infra/explorer"}])
      end
    end

    context "clear or retain existing breadcrumb path" do
      before { controller.stub(:render => nil, :build_toolbar => nil) }

      it 'it clears the existing breadcrumb path and assigns the new explorer path when controllers are switched' do
        session[:breadcrumbs] = [{:name => "Instances", :url => "/vm_cloud/explorer"}]
        controller.stub(:x_node).and_return("v-#{vm_vmware.compressed_id}")
        get :explorer
        expect(subject).to eq([{:name => "VM or Templates", :url => "/vm_infra/explorer"}])
      end

      it 'retains the breadcrumb path when cancel is pressed from a VM action' do
        get :explorer
        controller.stub(:x_node).and_return("v-#{vm_vmware.compressed_id}")
        post :x_button, :id => vm_vmware.id, :pressed => 'vm_ownership'

        controller.instance_variable_set(:@in_a_form, nil)
        post :ownership_update, :button => 'cancel'

        expect(subject).to eq([{:name => "VM or Templates", :url => "/vm_infra/explorer"}])
      end
    end
  end

  it "gets explorer when the request.referrer action is of type 'post'" do
    session[:settings] = {:views => {}, :perpage => {:list => 10}}
    request.stub(:referrer).and_return("http://localhost:3000/configuration/update")
    get :explorer
    expect(response.status).to eq(200)
  end
end

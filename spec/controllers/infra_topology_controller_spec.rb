describe InfraTopologyController do
  render_views
  before(:each) do
    stub_user(:features => :all)
  end

  it "renders index" do
    get :index
    expect(response.status).to eq(302)
    expect(response).to redirect_to(:action => 'show')
  end

  it "renders show screen per provider id" do
    EvmSpecHelper.create_guid_miq_server_zone
    ems = FactoryGirl.create(:ems_openstack)
    get :show, :params => { :id => ems.id }
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(response).to render_template('infra_topology/show')
  end

  it "renders show screen for all providers" do
    EvmSpecHelper.create_guid_miq_server_zone
    get :show
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(response).to render_template('infra_topology/show')
  end
end

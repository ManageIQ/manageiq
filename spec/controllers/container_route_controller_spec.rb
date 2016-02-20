describe ContainerRouteController do
  render_views
  before(:each) do
    set_user_privileges
  end

  it "renders index" do
    get :index
    expect(response.status).to eq(302)
    expect(response).to redirect_to(:action => 'show_list')
  end

  it "renders show screen" do
    EvmSpecHelper.create_guid_miq_server_zone
    ems = FactoryGirl.create(:ems_kubernetes)
    container_route = ContainerRoute.create(:ext_management_system => ems, :name => "Test Route")
    get :show, :params => { :id => container_route.id }
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(assigns(:breadcrumbs)).to eq([{:name => "Container Routes",
                                          :url  => "/container_route/show_list?page=&refresh=y"},
                                         {:name => "Test Route (Summary)",
                                          :url  => "/container_route/show/#{container_route.id}"}])
  end

  it "renders show_list" do
    session[:settings] = {:default_search => 'foo',
                          :views          => {:containerroute => 'list'},
                          :perpage        => {:list => 10}}

    EvmSpecHelper.create_guid_miq_server_zone

    get :show_list
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end
end

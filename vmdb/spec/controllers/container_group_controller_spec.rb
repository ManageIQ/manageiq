require "spec_helper"

describe ContainerGroupController do
  render_views
  before(:each) do
    set_user_privileges
  end

  it "renders index" do
    get :index
    expect(response.status).to eq(302)
    response.should redirect_to(:action => 'show_list')
  end

  it "renders show screen" do
    ems = FactoryGirl.create(:ext_management_system)
    container_group = ContainerGroup.create(:ext_management_system => ems, :name => "Test Group")
    get :show, :id => container_group.id
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(assigns(:breadcrumbs)).to eq([{:name => "Test Group (Summary)",
                                          :url  => "/container_group/show/#{container_group.id}"}])
  end

  it "renders show_list" do
    session[:settings] = {:default_search => 'foo',
                          :views          => {:containernode => 'list'},
                          :perpage        => {:list => 10}}
    session[:userid] = User.current_user.userid
    session[:eligible_groups] = []
    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone

    get :show_list
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end
end

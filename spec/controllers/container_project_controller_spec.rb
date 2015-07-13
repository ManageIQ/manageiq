require "spec_helper"

describe ContainerProjectController do
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
    MiqServer.stub(:my_zone).and_return("default")
    ems = FactoryGirl.create(:ems_kubernetes)
    container_project = ContainerProject.create(:ext_management_system => ems, :name => "Test Project")
    get :show, :id => container_project.id
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(assigns(:breadcrumbs)).to eq([:name => "Test Project (Summary)",
                                         :url  => "/container_project/show/#{container_project.id}"])
  end

  it "renders show_list" do
    session[:settings] = {:default_search => 'foo',
                          :views          => {:containerproject => 'list'},
                          :perpage        => {:list => 10}}

    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone

    get :show_list
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end
end

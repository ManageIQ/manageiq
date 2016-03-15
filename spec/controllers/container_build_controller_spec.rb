require "spec_helper"

describe ContainerBuildController do
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
    ems = FactoryGirl.create(:ems_openshift)
    container_build = ContainerBuild.create(:ext_management_system => ems, :name => "Test Build")
    get :show, :params => { :id => container_build.id }
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(assigns(:breadcrumbs)).to eq([{:name => "Builds",
                                          :url  => "/container_build/show_list?page=&refresh=y"},
                                         {:name => "Test Build (Summary)",
                                          :url  => "/container_build/show/#{container_build.id}"}])
  end

  it "renders show_list" do
    session[:settings] = {:default_search => 'foo',
                          :views          => {:containerbuild => 'list'},
                          :perpage        => {:list => 10}}

    EvmSpecHelper.create_guid_miq_server_zone

    get :show_list
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end
end

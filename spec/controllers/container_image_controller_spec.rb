require "spec_helper"

describe ContainerImageController do
  render_views
  before(:each) do
    set_user_privileges
  end

  it "when Smart Analysis is pressed" do
    controller.should_receive(:scan_images)
    post :button, :pressed => 'container_image_scan', :format => :js
    controller.send(:flash_errors?).should_not be_true
  end

  it "renders index" do
    get :index
    expect(response.status).to eq(302)
    response.should redirect_to(:action => 'show_list')
  end

  it "renders show screen" do
    EvmSpecHelper.create_guid_miq_server_zone
    ems = FactoryGirl.create(:ems_kubernetes)
    container_image = ContainerImage.create(:ext_management_system => ems, :name => "Test Image")
    get :show, :id => container_image.id
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(assigns(:breadcrumbs)).to eq([{:name => "Container Images",
                                          :url  => "/container_image/show_list?page=&refresh=y"},
                                         {:name => "Test Image (Summary)",
                                          :url  => "/container_image/show/#{container_image.id}"}])
  end

  it "renders show_list" do
    session[:settings] = {:default_search => 'foo',
                          :views          => {:containerimage => 'list'},
                          :perpage        => {:list => 10}}

    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone

    get :show_list
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end
end

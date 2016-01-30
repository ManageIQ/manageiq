describe ContainerImageController do
  render_views
  before(:each) do
    set_user_privileges
  end

  it "when Smart Analysis is pressed" do
    ApplicationController.handle_exceptions = true

    expect(controller).to receive(:scan_images)
    post :button, :pressed => 'container_image_scan', :format => :js
    expect(controller.send(:flash_errors?)).not_to be_truthy
  end

  it "renders index" do
    get :index
    expect(response.status).to eq(302)
    expect(response).to redirect_to(:action => 'show_list')
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

    EvmSpecHelper.create_guid_miq_server_zone

    get :show_list
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end
end

describe ContainerImageController do
  render_views
  before(:each) do
    stub_user(:features => :all)
  end

  it "when Smart Analysis is pressed" do
    ApplicationController.handle_exceptions = true

    expect(controller).to receive(:scan_images)
    post :button, :params => { :pressed => 'container_image_scan', :format => :js }
    expect(controller.send(:flash_errors?)).not_to be_truthy
  end

  it "when Check Compliance is pressed with no images" do
    ApplicationController.handle_exceptions = true

    expect(controller).to receive(:check_compliance).and_call_original
    expect(controller).to receive(:add_flash).with("Container Image no longer exists", :error)
    expect(controller).to receive(:add_flash).with("No Container Images were selected for Compliance Check", :error)
    post :button, :params => { :pressed => 'container_image_check_compliance', :format => :js }
  end

  it 'renders edit container image tags' do
    ApplicationController.handle_exceptions = true

    post :button, :params => {:pressed => "container_image_protect", :format => :js}
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
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
    get :show, :params => { :id => container_image.id }
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(assigns(:breadcrumbs)).to eq([{:name => "Container Images",
                                          :url  => "/container_image/show_list?page=&refresh=y"},
                                         {:name => "Test Image (Summary)",
                                          :url  => "/container_image/show/#{container_image.id}"}])
  end

  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      login_as FactoryGirl.create(:user)
      @image = FactoryGirl.create(:container_image)
    end

    subject { get :show, :id => @image.id }

    context "render" do
      render_views

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_container_image")
      end
    end
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

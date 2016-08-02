describe ContainerTemplateController do
  render_views
  before(:each) do
    stub_user(:features => :all)
  end

  it "renders index" do
    get :index
    expect(response.status).to eq(302)
    expect(response).to redirect_to(:action => 'show_list')
  end

  it "renders show screen" do
    EvmSpecHelper.create_guid_miq_server_zone
    ems = FactoryGirl.create(:ems_openshift)
    container_template = ContainerTemplate.create(:ext_management_system => ems, :name => "Test Template")
    get :show, :params => { :id => container_template.id }
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(assigns(:breadcrumbs)).to eq([{:name => "Container Templates",
                                          :url  => "/container_template/show_list?page=&refresh=y"},
                                         {:name => "Test Template (Summary)",
                                          :url  => "/container_template/show/#{container_template.id}"}])
  end

  it "renders show_list" do
    session[:settings] = {:default_search => 'foo',
                          :views          => {:containertemplate => 'list'},
                          :perpage        => {:list => 10}}

    EvmSpecHelper.create_guid_miq_server_zone

    get :show_list
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end

  it "renders grid view" do
    EvmSpecHelper.create_guid_miq_server_zone
    ems = FactoryGirl.create(:ems_openshift)
    container_template = ContainerTemplate.create(:ext_management_system => ems, :name => "Test Template")

    session[:settings] = {
      :views => {:containertemplate => "grid"}
    }

    post :show_list, :params => {:controller => 'container_template', :id => container_template.id}
    expect(response).to render_template('layouts/gtl/_grid')
    expect(response.status).to eq(200)
  end

  it "Controller method is called with correct parameters" do
    controller.params[:type] = "tile"
    controller.instance_variable_set(:@settings, :views => {:containertemplate => "list"})
    expect(controller).to receive(:get_view_calculate_gtl_type).with(:containertemplate) do
      expect(controller.instance_variable_get(:@settings)).to include(:views => {:containertemplate => "tile"})
    end
    controller.send(:get_view, "ContainerTemplate", :gtl_dbname => :containertemplate)
  end
end

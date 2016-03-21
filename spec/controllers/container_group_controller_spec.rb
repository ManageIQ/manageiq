describe ContainerGroupController do
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
    container_project = ContainerProject.create(:ext_management_system => ems)
    container_group = ContainerGroup.create(:ext_management_system => ems,
                                            :container_project     => container_project,
                                            :name                  => "Test Group")
    get :show, :params => { :id => container_group.id }
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(assigns(:breadcrumbs)).to eq([{:name => "Pods",
                                          :url  => "/container_group/show_list?page=&refresh=y"},
                                         {:name => "Test Group (Summary)",
                                          :url  => "/container_group/show/#{container_group.id}"}])
  end

  it "renders show_list" do
    session[:settings] = {:default_search => 'foo',
                          :views          => {:containergroup => 'list'},
                          :perpage        => {:list => 10}}
    EvmSpecHelper.create_guid_miq_server_zone

    get :show_list
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end

  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @container_group = FactoryGirl.create(:container_group_with_assoc)
      login_as FactoryGirl.create(:user)
    end

    subject { get :show, :id => @container_group.id }

    context "render" do
      render_views

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_container_group")
      end
    end
  end
end

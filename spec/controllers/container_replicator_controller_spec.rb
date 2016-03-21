describe ContainerReplicatorController do
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
    container_replicator = ContainerReplicator.create(
      :ext_management_system => ems,
      :container_project     => ContainerProject.create(:ext_management_system => ems, :name => "test"),
      :name                  => "Test Replicator"
    )
    get :show, :params => { :id => container_replicator.id }
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
    expect(assigns(:breadcrumbs)).to eq([{:name => "Container Replicators",
                                          :url  => "/container_replicator/show_list?page=&refresh=y"},
                                         {:name => "Test Replicator (Summary)",
                                          :url  => "/container_replicator/show/#{container_replicator.id}"}])
  end

  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      login_as FactoryGirl.create(:user)
      @replicator = FactoryGirl.create(:replicator_with_assoc)
    end

    subject { get :show, :id => @replicator.id }

    context "render" do
      render_views

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_container_replicator")
      end
    end
  end

  it "renders show_list" do
    session[:settings] = {:default_search => 'foo',
                          :views          => {:containerreplicator => 'list'},
                          :perpage        => {:list => 10}}

    EvmSpecHelper.create_guid_miq_server_zone

    get :show_list
    expect(response.status).to eq(200)
    expect(response.body).to_not be_empty
  end
end

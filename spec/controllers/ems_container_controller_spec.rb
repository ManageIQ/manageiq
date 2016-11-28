describe EmsContainerController do
  before(:each) do
    stub_user(:features => :all)
  end

  it "#new" do
    controller.instance_variable_set(:@breadcrumbs, [])
    get :new

    expect(response.status).to eq(200)
    expect(allow(controller).to receive(:edit)).to_not be_nil
  end

  describe "#show" do
    before do
      session[:settings] = {:views => {}, :quadicons => {}}
      EvmSpecHelper.create_guid_miq_server_zone
      login_as FactoryGirl.create(:user)
      @container = FactoryGirl.create(:ems_kubernetes)
    end

    subject { get :show, :id => @container.id }

    context "render" do
      render_views
      it { is_expected.to render_template('shared/views/ems_common/show') }

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_ems_container")
      end

      it "renders topology view" do
        get :show, :params => { :id => @container.id, :display => 'topology' }
        expect(response.status).to eq(200)
        expect(response.body).to_not be_empty
        expect(response).to render_template('container_topology/show')
      end
    end
  end
end

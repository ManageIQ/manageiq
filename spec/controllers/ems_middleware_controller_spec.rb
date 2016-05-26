describe EmsMiddlewareController do
  before(:each) do
    set_user_privileges
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
      @middleware = FactoryGirl.create(:ems_hawkular)
      MiddlewareDatasource.create(:ext_management_system => @middleware, :name => "Test Middleware")
    end

    subject { get :show, :id => @middleware.id }

    context "render" do
      render_views
      it { is_expected.to render_template('ems_middleware/show') }

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_ems_middleware")
      end
    end
  end
end

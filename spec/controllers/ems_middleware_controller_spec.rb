describe EmsMiddlewareController do
  let!(:server) { EvmSpecHelper.local_miq_server(:zone => zone) }
  let(:zone) { FactoryGirl.build(:zone) }
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
      @middleware = FactoryGirl.create(:ems_hawkular)
      MiddlewareDatasource.create(:ext_management_system => @middleware, :name => "Test Middleware")
    end

    subject { get :show, :id => @middleware.id }

    context "render" do
      render_views
      it { is_expected.to render_template('shared/views/ems_common/show') }

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_ems_middleware")
      end
    end
  end

  describe "Hawkular - create, update" do
    before do
      allow(controller).to receive(:check_privileges).and_return(true)
      allow(controller).to receive(:assert_privileges).and_return(true)
      login_as FactoryGirl.create(:user, :features => "ems_middleware_new")
    end

    render_views

    it 'creates on post' do
      expect do
        post :create, :params => {
          "button"           => "add",
          "name"             => "SeaHawks",
          "emstype"          => "hawkular",
          "zone"             => zone.name,
          "cred_type"        => "default",
          "default_hostname" => "foo.com",
          "default_userid"   => "foo",
          "default_password" => "[FILTERED]",
          "default_verify"   => "[FILTERED]"
        }
      end.to change { ManageIQ::Providers::Hawkular::MiddlewareManager.count }.by(1)
    end

    it 'creates and updates an authentication record on post' do
      expect do
        post :create, :params => {
          "button"           => "add",
          "name"             => "SeaHawks",
          "emstype"          => "hawkular",
          "zone"             => zone.name,
          "cred_type"        => "default",
          "default_hostname" => "foo.com",
          "default_userid"   => "foo",
          "default_password" => "[FILTERED]",
          "default_verify"   => "[FILTERED]"
        }
      end.to change { Authentication.count }.by(1)

      expect(response.status).to eq(200)
      hawkular = ManageIQ::Providers::Hawkular::MiddlewareManager.where(:name => "SeaHawks").first
      expect(hawkular.authentications.size).to eq(1)

      expect do
        post :update, :params => {
          "id"               => hawkular.id,
          "button"           => "save",
          "default_hostname" => "host_hawkular_updated",
          "name"             => "SeaHawks",
          "emstype"          => "hawkular",
          "default_userid"   => "bar",
          "default_password" => "[FILTERED]",
          "default_verify"   => "[FILTERED]"
        }
      end.not_to change { Authentication.count }

      expect(response.status).to eq(200)
      expect(hawkular.authentications.first).to have_attributes(:userid => "bar", :password => "[FILTERED]")
    end
  end
end

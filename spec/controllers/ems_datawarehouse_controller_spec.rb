describe EmsDatawarehouseController do
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
      @dwh = FactoryGirl.create(:ems_hawkular_datawarehouse)
    end

    subject { get :show, :id => @dwh.id }

    context "render" do
      render_views
      it { is_expected.to render_template('shared/views/ems_common/show') }

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_ems_datawarehouse")
      end
    end
  end

  describe "Datawarehouse - create, update" do
    before do
      allow(controller).to receive(:check_privileges).and_return(true)
      allow(controller).to receive(:assert_privileges).and_return(true)
      login_as FactoryGirl.create(:user, :features => "ems_datawarehouse_new")
    end

    render_views

    it 'creates on post' do
      expect do
        post :create, :params => {
          "button"           => "add",
          "cred_type"        => "default",
          "name"             => "lotsofdata",
          "emstype"          => "hawkular_datawarehouse",
          "zone"             => zone.name,
          "default_hostname" => "lotsofdata.com",
          "default_api_port" => "443",
          "default_userid"   => "",
          "default_password" => "VERY_SECRET",
          "default_verify"   => "VERY_SECRET",
        }
      end.to change { ManageIQ::Providers::Hawkular::DatawarehouseManager.count }.by(1)
    end

    it 'creates and updates an authentication record on post' do
      expect do
        post :create, :params => {
          "button"           => "add",
          "cred_type"        => "default",
          "name"             => "lotsofdata",
          "emstype"          => "hawkular_datawarehouse",
          "zone"             => zone.name,
          "default_hostname" => "lotsofdata.com",
          "default_userid"   => "",
          "default_password" => "VERY_SECRET",
          "default_verify"   => "VERY_SECRET"
        }
      end.to change { Authentication.count }.by(1)

      expect(response.status).to eq(200)
      dwh = ManageIQ::Providers::Hawkular::DatawarehouseManager.where(:name => "lotsofdata").first
      expect(dwh.authentications.size).to eq(1)

      expect do
        post :update, :params => {
          "id"               => dwh.id,
          "button"           => "save",
          "cred_type"        => "default",
          "name"             => "not_so_much_data",
          "emstype"          => "hawkular_datawarehouse",
          "default_hostname" => "host_hawkular_updated",
          "default_userid"   => "",
          "default_password" => "MUCH_WOW",
          "default_verify"   => "MUCH_WOW"
        }
      end.not_to change { Authentication.count }

      expect(response.status).to eq(200)
      dwh.reload
      expect(dwh.name).to eq("not_so_much_data")
      expect(dwh.authentications.first).to have_attributes(:auth_key => "MUCH_WOW")
    end
  end
end

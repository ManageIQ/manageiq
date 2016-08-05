describe MiddlewareDomainController do
  render_views
  before(:each) do
    stub_user(:features => :all)
  end

  it 'renders index' do
    get :index
    expect(response.status).to eq(302)
    expect(response).to redirect_to(:action => 'show_list')
  end

  describe '#show' do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      login_as FactoryGirl.create(:user)
      @domain = FactoryGirl.create(:hawkular_middleware_domain,
                                   :name       => 'master',
                                   :nativeid   => 'Local~/host=master',
                                   :properties => {
                                     'Running Mode'         => 'NORMAL',
                                     'Version'              => '9.0.2.Final',
                                     'Product Name'         => 'WildFly Full',
                                     'Host State'           => 'running',
                                     'Is Domain Controller' => 'true',
                                     'Name'                 => 'master',
                                   })
    end

    subject { get :show, :id => @domain.id }

    context 'render' do
      render_views

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => 'layouts/listnav/_middleware_domain')
        is_expected.to render_template(:partial => 'middleware_domain/_main')
      end
    end
  end
end

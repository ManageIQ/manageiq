describe MiddlewareJmsController do
  render_views
  before(:each) do
    set_user_privileges
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
      @jms = FactoryGirl.create(:hawkular_middleware_jms_initialized)
    end

    subject { get :show, :id => @jms.id }

    context 'render' do
      render_views

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => 'layouts/listnav/_middleware_jms')
        is_expected.to render_template(:partial => 'middleware_jms/_main')
      end
    end
  end
end

describe RestfulRedirectController do
  let(:user) { FactoryGirl.create(:user_with_email, :role => 'super_administrator', :password => 'x') }

  before do
    EvmSpecHelper.create_guid_miq_server_zone
  end

  before :each do
    post '/dashboard/authenticate', :params => { :user_name => user.userid, :user_password => user.password }
  end

  context 'for MiqRequest' do
    let(:ems)      { FactoryGirl.create(:ems_vmware_with_authentication) }
    let(:template) { FactoryGirl.create(:template_vmware, :ext_management_system => ems) }
    let(:req) { FactoryGirl.create(:miq_provision_request, :requester => user, :source => template) }

    before do
      MiqDialog.seed
    end

    it 'redirects' do
      get '/restful_redirect', :params => { :model => 'MiqRequest', :id => req.id }
      expect(response).to redirect_to(:controller => 'miq_request', :action => 'show', :id => req.id)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)
      expect(response.body).to include(req.message)
    end
  end
end

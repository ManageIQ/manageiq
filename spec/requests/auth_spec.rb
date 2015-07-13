require 'spec_helper'

describe "Login process" do
  before(:each) do
    Vmdb::Application.config.secret_token = 'x' * 40
    EvmSpecHelper.seed_admin_user_and_friends

    ApplicationController.any_instance.stub(:set_user_time_zone)
    MiqEnvironment::Process.stub(:is_web_server_worker?).and_return(true)
  end

  context "w/o a valid session" do
    pending "these tests are failing on CC monitor" do
      it "redirects to 'login'" do
        get '/dashboard/show'
        expect(response).to redirect_to(:controller => 'dashboard', :action => 'login')
      end

      it "redirects to 'login' and sets start_url for whitelisted entry point" do
        get '/host/show/10'
        expect(response).to redirect_to(:controller => 'dashboard', :action => 'login')
        expect(session[:start_url]).to eq('http://www.example.com/host/show/10')
      end

      it "allows login with correct password" do
        post '/dashboard/authenticate', :user_name => 'admin', :user_password => 'smartvm'
        expect(response.status).to eq(200)
        expect(response.body).not_to match(/password you entered is incorrect/)
      end

      it "does now allow login with incorrect password" do
        post '/dashboard/authenticate', :user_name => 'admin', :user_password => 'fantomas'
        expect(response.status).to eq(200)
        expect(response.body).to match(/password you entered is incorrect/)
      end
    end
  end

  context 'w/ a valid session' do
    it "allows access w/ a valid referer" do
      post '/dashboard/authenticate', :user_name => 'admin', :user_password => 'smartvm'
      get '/ems_cloud/show_list', nil, 'HTTP_REFERER' => "http://www.example.com/"
      expect(response.status).to eq(200)
    end

    it "does not allow access w/o a valid referer" do
      post '/dashboard/authenticate', :user_name => 'admin', :user_password => 'smartvm'
      get '/ems_cloud/show_list', nil, 'HTTP_REFERER' => "http://foo.bar.com"
      expect(response.status).to eq(403)
    end

    it "allows access w/o a valid referer to a whitelisted entry point" do
      post '/dashboard/authenticate', :user_name => 'admin', :user_password => 'smartvm'
      host = FactoryGirl.create(:host)
      get "/host/show/#{host.id}"
      expect(response.status).to eq(200)
    end
  end
end

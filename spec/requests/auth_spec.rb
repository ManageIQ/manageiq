describe "Login process" do
  let(:user) do
    FactoryGirl.create(:user_with_email, :password => "smartvm", :role => "super_administrator")
  end

  before(:each) do
    EvmSpecHelper.local_miq_server
    user
  end

  context "w/o a valid session" do
    it "redirects to 'login'" do
      get '/dashboard/show'
      expect(response).to redirect_to(:controller => 'dashboard', :action => 'login', :timeout => false)
    end

    it "redirects to 'login' and sets start_url for whitelisted entry point" do
      get '/host/show/10'
      expect(response).to redirect_to(:controller => 'dashboard', :action => 'login', :timeout => false)
      expect(session[:start_url]).to eq('http://www.example.com/host/show/10')
    end

    it "allows login with correct password" do
      post '/dashboard/authenticate', :params => { :user_name => user.userid, :user_password => 'smartvm' }
      expect(response.status).to eq(200)
      expect(response.body).not_to match(/password you entered is incorrect/)
    end

    it "does now allow login with incorrect password" do
      post '/dashboard/authenticate', :params => { :user_name => user.userid, :user_password => 'fantomas' }
      expect(response.status).to eq(200)
      expect(response.body).to match(/password you entered is incorrect/)
    end
  end

  context 'w/ a valid session' do
    it "allows access w/ a valid referer" do
      post '/dashboard/authenticate', :params => { :user_name => user.userid, :user_password => 'smartvm' }
      get '/ems_cloud/show_list', :headers => { 'Referer' => "http://www.example.com/" }
      expect(response.status).to eq(200)
    end

    it "does not allow access w/o a valid referer" do
      post '/dashboard/authenticate', :params => { :user_name => user.userid, :user_password => 'smartvm' }
      get '/ems_cloud/show_list', :headers => { 'Referer' => "http://foo.bar.com" }
      expect(response.status).to eq(403)
    end

    it "allows access w/o a valid referer to a whitelisted entry point" do
      post '/dashboard/authenticate', :params => { :user_name => user.userid, :user_password => 'smartvm' }
      host = FactoryGirl.create(:host)
      get "/host/show/#{host.id}"
      expect(response.status).to eq(200)
    end
  end
end

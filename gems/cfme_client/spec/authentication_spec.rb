describe "CfmeClient Authentication" do
  before do
    @cfme = init_api
  end

  context "Basic Authentication" do
    it "test basic authentication with bad credentials" do
      success = @cfme[:client].entrypoint(:user => "baduser", :password => "badpassword")
      test_api?

      expect(success).to eq false
      expect(@cfme[:client].code).to eq(401)
    end

    it "test basic authentication with correct credentials" do
      success = @cfme[:client].entrypoint(:user => @cfme[:user], :password => @cfme[:password])
      test_api?

      expect(success).to eq true
      expect(@cfme[:client].code).to eq(200)
    end
  end

  context "Token Based Authentication" do
    it "gets a token based identifier" do
      success = @cfme[:client].authenticate(:user => @cfme[:user], :password => @cfme[:password])
      test_api?

      expect(success).to eq true
      expect(@cfme[:client].result).to have_key("auth_token")
      @cfme[:auth_token] = @cfme[:client].result["auth_token"]
    end

    it "authentication using a bad token" do
      success = @cfme[:client].entrypoint(:auth_token => "badtoken")
      test_api?

      expect(success).to eq false
      expect(@cfme[:client].code).to eq(401)
    end

    it "authentication using a valid token" do
      success = @cfme[:client].authenticate(:user => @cfme[:user], :password => @cfme[:password])
      test_api?

      expect(success).to eq true
      expect(@cfme[:client].result).to have_key("auth_token")
      @cfme[:auth_token] = @cfme[:client].result["auth_token"]
      success = @cfme[:client].entrypoint(:auth_token => @cfme[:auth_token])
      expect(success).to eq true
      expect(@cfme[:client].code).to eq(200)
    end
  end
end

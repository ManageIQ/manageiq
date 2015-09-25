#
# Tests to exercise the CfmeClient
#
# Requires EVM to be running
#

require 'spec_helper'

describe "CfmeClient Authentication" do

  before do
    @cfme = init_api
  end

  context "Basic Authentication" do

    it "test basic authentication with bad credentials" do
      success = @cfme[:client].entrypoint(:user => "baduser", :password => "badpassword")
      if test_api?
        expect(success).to be_false
        expect(@cfme[:client].code).to eq(401)
      end
    end

    it "test basic authentication with correct credentials" do
      success = @cfme[:client].entrypoint(:user => @cfme[:user], :password => @cfme[:password])
      if test_api?
        expect(success).to be_true
        expect(@cfme[:client].code).to eq(200)
      end
    end

  end

  context "Token Based Authentication" do

    it "gets a token based identifier" do
      success = @cfme[:client].authenticate(:user => @cfme[:user], :password => @cfme[:password])
      if test_api?
        expect(success).to be_true
        expect(@cfme[:client].result).to have_key("auth_token")
        @cfme[:auth_token] = @cfme[:client].result["auth_token"]
      end
    end

    it "authentication using a bad token" do
      success = @cfme[:client].entrypoint(:auth_token => "badtoken")
      if test_api?
        expect(success).to be_false
        expect(@cfme[:client].code).to eq(401)
      end
    end

    it "authentication using a valid token" do
      success = @cfme[:client].authenticate(:user => @cfme[:user], :password => @cfme[:password])
      if test_api?
        expect(success).to be_true
        expect(@cfme[:client].result).to have_key("auth_token")
        @cfme[:auth_token] = @cfme[:client].result["auth_token"]
        success = @cfme[:client].entrypoint(:auth_token => @cfme[:auth_token])
        expect(success).to be_true
        expect(@cfme[:client].code).to eq(200)
      end
    end

  end

end

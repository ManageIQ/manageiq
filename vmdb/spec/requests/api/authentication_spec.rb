#
# REST API Request Tests - /api authentication
#
require 'spec_helper'

describe ApiController do

  include Rack::Test::Methods

  before(:each) do
    init_api_spec_env
  end

  def app
    Vmdb::Application
  end

  context "Basic Authentication" do

    it "test basic authentication with bad credentials" do
      basic_authorize "baduser", "badpassword"
      @success = run_get @cfme[:entrypoint]
      expect(@success).to be_false
      expect(@code).to eq(401)
    end

    it "test basic authentication with correct credentials" do
      basic_authorize @cfme[:user], @cfme[:password]
      @success = run_get @cfme[:entrypoint]
      expect(@success).to be_true
      expect(@code).to eq(200)
    end

  end

  context "Token Based Authentication" do

    it "gets a token based identifier" do
      basic_authorize @cfme[:user], @cfme[:password]
      @success = run_get @cfme[:auth_url]
      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("auth_token")
    end

    it "authentication using a bad token" do
      @success = run_get @cfme[:entrypoint], "auth_token" => "badtoken"
      expect(@success).to be_false
      expect(@code).to eq(401)
    end

    it "authentication using a valid token" do
      basic_authorize @cfme[:user], @cfme[:password]
      @success = run_get @cfme[:auth_url]
      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("auth_token")
      auth_token = @result["auth_token"]
      @success = run_get @cfme[:entrypoint], "auth_token" => auth_token
      expect(@success).to be_true
      expect(@code).to eq(200)
    end

  end

end

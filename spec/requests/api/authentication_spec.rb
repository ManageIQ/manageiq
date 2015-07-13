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

      run_get entrypoint_url

      expect_user_unauthorized
    end

    it "test basic authentication with correct credentials" do
      api_basic_authorize

      run_get entrypoint_url

      expect_single_resource_query
      expect_result_to_have_keys(%w(name description version versions collections))
    end
  end

  context "Token Based Authentication" do
    it "gets a token based identifier" do
      api_basic_authorize

      run_get auth_url

      expect_single_resource_query
      expect_result_to_have_keys(%w(auth_token expires_on))
    end

    it "authentication using a bad token" do
      run_get entrypoint_url, :headers => {"auth_token" => "badtoken"}

      expect_user_unauthorized
    end

    it "authentication using a valid token" do
      api_basic_authorize

      run_get auth_url

      expect_single_resource_query
      expect_result_to_have_keys(%w(auth_token))

      auth_token = @result["auth_token"]

      run_get entrypoint_url, :headers => {"auth_token" => auth_token}

      expect_single_resource_query
      expect_result_to_have_keys(%w(name description version versions collections))
    end
  end
end

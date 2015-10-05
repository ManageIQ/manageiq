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
      expect_result_to_have_keys(%w(auth_token token_ttl expires_on))
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

    it "authentication using a valid token updates the token's expiration time" do
      api_basic_authorize

      run_get auth_url

      expect_single_resource_query
      expect_result_to_have_keys(%w(auth_token token_ttl expires_on))

      auth_token = @result["auth_token"]
      token_expires_on = @result["expires_on"]

      tm = TokenManager.new("api")
      token_info = tm.token_get_info("api", auth_token)
      expect(token_info[:expires_on].utc.iso8601).to eq(token_expires_on)

      expect_any_instance_of(TokenManager).to receive(:reset_token).with("api", auth_token)
      run_get entrypoint_url, :headers => {"auth_token" => auth_token}

      expect_single_resource_query
      expect_result_to_have_keys(%w(name description version versions collections))
    end

    it "gets a token based identifier with the default API based token_ttl" do
      api_basic_authorize

      api_token_ttl = VMDB::Config.new("vmdb").config[:api][:token_ttl].to_i_with_method
      run_get auth_url

      expect_single_resource_query
      expect_result_to_have_keys(%w(auth_token token_ttl expires_on))
      expect(@result["token_ttl"]).to eq(api_token_ttl)
    end

    it "gets a token based identifier with an invalid requester_type" do
      api_basic_authorize

      run_get auth_url, :requester_type => "bogus_type"

      expect_bad_request(/invalid requester_type/i)
    end

    it "gets a token based identifier with a UI based token_ttl" do
      api_basic_authorize

      ui_token_ttl = VMDB::Config.new("vmdb").config[:session][:timeout].to_i_with_method
      run_get auth_url, :requester_type => "ui"

      expect_single_resource_query
      expect_result_to_have_keys(%w(auth_token token_ttl expires_on))
      expect(@result["token_ttl"]).to eq(ui_token_ttl)
    end
  end
end

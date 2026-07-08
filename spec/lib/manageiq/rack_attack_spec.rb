require 'rack/attack'

RSpec.describe ManageIQ::RackAttack do
  include Rack::Test::Methods

  let(:app) do
    Rack::Builder.new do
      use Rack::Attack
      run ->(_env) { [200, {}, ["OK"]] }
    end.to_app
  end

  before do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    stub_settings_merge(
      :server => {
        :rate_limiting => {
          :api_login => {:limit => 5, :period => 20},
          :request   => {:limit => 20, :period => 300},
          :ui_login  => {:limit => 10, :period => 20}
        }
      }
    )
    # The middleware registration is already done at boot; skip it here so we
    # only exercise the throttle configuration.
    allow(Rails.application.middleware).to receive(:use)
    ManageIQ::RackAttack.configure
    # configure disables Rack::Attack for non-server processes; re-enable for tests
    Rack::Attack.enabled = true
  end

  after do
    Rack::Attack.enabled = false
    Rack::Attack.clear_configuration
  end

  describe "req/ip throttle" do
    def make_request = get("/some/path", {}, "REMOTE_ADDR" => "1.2.3.4")

    it "allows requests under the limit" do
      make_request
      expect(last_response.status).to eq(200)
    end

    it "throttles after exceeding the request limit" do
      20.times { make_request }
      expect(last_response.status).to eq(200)

      make_request
      expect(last_response.status).to eq(429)
    end

    it "tracks each IP independently" do
      20.times { make_request }

      get "/some/path", {}, "REMOTE_ADDR" => "5.6.7.8"
      expect(last_response.status).to eq(200)
    end
  end

  describe "api_logins/ip throttle" do
    it "throttles GET /api/auth at the login limit" do
      5.times { get "/api/auth", {}, "REMOTE_ADDR" => "1.2.3.4" }
      expect(last_response.status).to eq(200)

      get "/api/auth", {}, "REMOTE_ADDR" => "1.2.3.4"
      expect(last_response.status).to eq(429)
    end

    it "does not apply the login throttle to non-GET requests but still applies request throttle" do
      20.times { delete "/api/auth", {}, "REMOTE_ADDR" => "1.2.3.4" }
      expect(last_response.status).to eq(200)

      delete "/api/auth", {}, "REMOTE_ADDR" => "1.2.3.4"
      expect(last_response.status).to eq(429)
    end

    it "does not apply the throttle to other /api/* paths" do
      6.times { get "/api/vms", {}, "REMOTE_ADDR" => "1.2.3.4" }
      expect(last_response.status).to eq(200)
    end
  end

  describe "basic_auth/ip throttle" do
    let(:basic_auth_header) { {"HTTP_AUTHORIZATION" => "Basic dXNlcjpwYXNz", "REMOTE_ADDR" => "1.2.3.4"} }

    it "throttles Basic auth requests at the login limit" do
      5.times { get "/api/vms", {}, basic_auth_header }
      expect(last_response.status).to eq(200)

      get "/api/vms", {}, basic_auth_header
      expect(last_response.status).to eq(429)
    end

    it "does not apply the login throttle to requests without an Authorization header but still applies request throttle" do
      20.times { get "/api/vms", {}, "REMOTE_ADDR" => "1.2.3.4" }
      expect(last_response.status).to eq(200)

      get "/api/vms", {}, "REMOTE_ADDR" => "1.2.3.4"
      expect(last_response.status).to eq(429)
    end

    it "does not apply the login throttle to Bearer auth requests but still applies request throttle" do
      bearer_header = {"HTTP_AUTHORIZATION" => "Bearer sometoken", "REMOTE_ADDR" => "1.2.3.4"}

      20.times { get "/api/vms", {}, bearer_header }
      expect(last_response.status).to eq(200)

      get "/api/vms", {}, bearer_header
      expect(last_response.status).to eq(429)
    end
  end

  describe "ui_logins/ip throttle" do
    it "throttles POST /dashboard/authenticate after exceeding the login limit" do
      10.times { post "/dashboard/authenticate", {}, "REMOTE_ADDR" => "1.2.3.4" }
      expect(last_response.status).to eq(200)

      post "/dashboard/authenticate", {}, "REMOTE_ADDR" => "1.2.3.4"
      expect(last_response.status).to eq(429)
    end

    it "does not apply the login throttle to non-POST requests but still applies request throttle" do
      20.times { get "/dashboard/authenticate", {}, "REMOTE_ADDR" => "1.2.3.4" }
      expect(last_response.status).to eq(200)

      get "/dashboard/authenticate", {}, "REMOTE_ADDR" => "1.2.3.4"
      expect(last_response.status).to eq(429)
    end
  end
end

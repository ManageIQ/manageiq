#
# REST API Logging Tests
#
describe "Logging" do
  describe "Successful Requests logging" do
    EXPECTED_LOGGED_PARAMETERS = {
      "API Request"    => nil,
      "Authentication" => nil,
      "Authorization"  => nil,
      "Request"        => nil,
      "Parameters"     => nil,
      "Response"       => nil
    }.freeze

    EXPECTED_SYSTEM_AUTH_LOGGED_PARAMETERS = {
      "API Request"    => nil,
      "System Auth"    => nil,
      "Authentication" => nil,
      "Authorization"  => nil,
      "Request"        => nil,
      "Parameters"     => nil,
      "Response"       => nil
    }.freeze

    def expect_log_requests(expectations)
      expectations.each do |category, expectation|
        expect_any_instance_of(Api::BaseController).to receive(:log_request)
          .with(category, expectation ? expectation : kind_of(Hash))
      end
    end

    it "logs hashed details about the request" do
      api_basic_authorize collection_action_identifier(:users, :read, :get)

      log_request_expectations = EXPECTED_LOGGED_PARAMETERS.merge(
        "Request" => a_hash_including(:path          => "/api/users",
                                      :collection    => "users",
                                      :c_id          => nil,
                                      :subcollection => nil,
                                      :s_id          => nil)
      )

      expect_log_requests(log_request_expectations)

      run_get users_url
    end

    it "logs all hash entries about the request" do
      api_basic_authorize

      log_request_expectations = EXPECTED_LOGGED_PARAMETERS.merge(
        "Request" => a_hash_including(:method, :action, :fullpath, :url, :base, :path, :prefix, :version, :api_prefix,
                                      :collection, :c_suffix, :c_id, :subcollection, :s_id)
      )

      expect_log_requests(log_request_expectations)

      run_get entrypoint_url
    end

    it "filters password attributes in nested parameters" do
      api_basic_authorize collection_action_identifier(:services, :create)

      log_request_expectations = EXPECTED_LOGGED_PARAMETERS.merge(
        "Parameters" => a_hash_including(
          "action"     => "update",
          "format"     => "json",
          "controller" => "api/services",
          "body"       => a_hash_including(
            "resource" => a_hash_including(
              "options" => a_hash_including("password" => "[FILTERED]")
            )
          )
        )
      )

      expect_log_requests(log_request_expectations)

      run_post(services_url, gen_request(:create, "name" => "new_service_1", "options" => { "password" => "SECRET" }))
    end

    it "logs additional system authentication with miq_token" do
      server_guid = MiqServer.first.guid
      userid = api_config(:user)
      timestamp = Time.now.utc

      miq_token = MiqPassword.encrypt({:server_guid => server_guid, :userid => userid, :timestamp => timestamp}.to_yaml)

      log_request_expectations = EXPECTED_SYSTEM_AUTH_LOGGED_PARAMETERS.merge(
        "System Auth"    => a_hash_including(
          :x_miq_token => miq_token, :server_guid => server_guid, :userid => userid, :timestamp => timestamp
        ),
        "Authentication" => a_hash_including(:type => "system", :user => "api_user_id"),
      )

      expect_log_requests(log_request_expectations)

      run_get entrypoint_url, :headers => {Api::HttpHeaders::MIQ_TOKEN => miq_token}
    end
  end
end

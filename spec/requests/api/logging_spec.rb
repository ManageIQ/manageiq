#
# REST API Logging Tests
#
describe ApiController do
  describe "Successful Requests logging" do
    EXPECTED_LOGGED_PARAMETERS = {
      "API Request"    => nil,
      "Authentication" => nil,
      "Authorization"  => nil,
      "Request"        => nil,
      "Parameters"     => nil,
      "Response"       => nil
    }.freeze

    def expect_log_requests(expectations)
      expectations.each do |category, expectation|
        expect_any_instance_of(ApiController).to receive(:log_request)
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
        "Request" => a_hash_including(:method, :fullpath, :url, :base, :path, :prefix, :version, :api_prefix,
                                      :collection, :c_suffix, :c_id, :subcollection, :s_id)
      )

      expect_log_requests(log_request_expectations)

      run_get entrypoint_url
    end
  end
end

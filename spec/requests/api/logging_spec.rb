#
# REST API Logging Tests
#
describe "Logging" do
  describe "Successful Requests logging" do
    it "logs hashed details about the request" do
      api_basic_authorize collection_action_identifier(:users, :read, :get)

      expect_any_instance_of(Api::UsersController).to receive(:log_request).with("API Request", a_kind_of(Hash))
      expect_any_instance_of(Api::UsersController).to receive(:log_request).with("Authentication", a_kind_of(Hash))
      expect_any_instance_of(Api::UsersController).to receive(:log_request).with("Authorization", a_kind_of(Hash))
      expect_any_instance_of(Api::UsersController).to receive(:log_request).with("Request", a_hash_including(
                                                                                  :path          => "/api/users",
                                                                                  :collection    => "users",
                                                                                  :c_id          => nil,
                                                                                  :subcollection => nil,
                                                                                  :s_id          => nil))
      expect_any_instance_of(Api::UsersController).to receive(:log_request).with("Parameters", a_kind_of(Hash))
      expect_any_instance_of(Api::UsersController).to receive(:log_request).with("Response", a_kind_of(Hash))

      run_get users_url
    end

    it "logs all hash entries about the request" do
      api_basic_authorize

      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("API Request", a_kind_of(Hash))
      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("Authentication", a_kind_of(Hash))
      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("Authorization", a_kind_of(Hash))
      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("Request", a_hash_including(
                                                                                 :method,
                                                                                 :action,
                                                                                 :fullpath,
                                                                                 :url,
                                                                                 :base,
                                                                                 :path,
                                                                                 :prefix,
                                                                                 :version,
                                                                                 :api_prefix,
                                                                                 :collection,
                                                                                 :c_suffix,
                                                                                 :c_id,
                                                                                 :subcollection,
                                                                                 :s_id))
      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("Parameters", a_kind_of(Hash))
      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("Response", a_kind_of(Hash))

      run_get entrypoint_url
    end

    it "filters password attributes in nested parameters" do
      api_basic_authorize collection_action_identifier(:services, :create)

      expect_any_instance_of(Api::ServicesController).to receive(:log_request).with("API Request", a_kind_of(Hash))
      expect_any_instance_of(Api::ServicesController).to receive(:log_request).with("Authentication", a_kind_of(Hash))
      expect_any_instance_of(Api::ServicesController).to receive(:log_request).with("Authorization", a_kind_of(Hash))
      expect_any_instance_of(Api::ServicesController).to receive(:log_request).with("Request", a_kind_of(Hash))
      expect_any_instance_of(Api::ServicesController).to receive(:log_request).with("Parameters", a_hash_including(
                                                                                      "action"     => "update",
                                                                                      "format"     => "json",
                                                                                      "controller" => "api/services",
                                                                                      "body"       => a_hash_including(
                                                                                        "resource" => a_hash_including(
                                                                                          "options" => a_hash_including("password" => "[FILTERED]")))))
      expect_any_instance_of(Api::ServicesController).to receive(:log_request).with("Response", a_kind_of(Hash))

      run_post(services_url, gen_request(:create, "name" => "new_service_1", "options" => { "password" => "SECRET" }))
    end

    it "logs additional system authentication with miq_token" do
      server_guid = MiqServer.first.guid
      userid = api_config(:user)
      timestamp = Time.now.utc

      miq_token = MiqPassword.encrypt({:server_guid => server_guid, :userid => userid, :timestamp => timestamp}.to_yaml)

      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("API Request", a_kind_of(Hash))
      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("System Auth", a_hash_including(
                                                                                   :x_miq_token => miq_token,
                                                                                   :server_guid => server_guid,
                                                                                   :userid => userid,
                                                                                   :timestamp => timestamp))
      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("Authentication", a_hash_including(
                                                                                   :type => "system",
                                                                                   :user => "api_user_id"))
      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("Authorization", a_kind_of(Hash))
      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("Request", a_kind_of(Hash))
      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("Parameters", a_kind_of(Hash))
      expect_any_instance_of(Api::ApiController).to receive(:log_request).with("Response", a_kind_of(Hash))

      run_get entrypoint_url, :headers => {Api::HttpHeaders::MIQ_TOKEN => miq_token}
    end
  end
end

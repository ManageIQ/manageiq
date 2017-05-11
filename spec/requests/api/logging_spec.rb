#
# REST API Logging Tests
#
describe "Logging" do
  describe "Successful Requests logging" do
    before { allow($api_log).to receive(:info) }

    it "logs hashed details about the request" do
      api_basic_authorize collection_action_identifier(:users, :read, :get)

      expect($api_log).to receive(:info).with(a_string_matching(/Request:/)
                                               .and(matching(%r{:path=>"/api/users"}))
                                               .and(matching(/:collection=>"users"/))
                                               .and(matching(/:c_id=>nil/))
                                               .and(matching(/:subcollection=>nil/))
                                               .and(matching(/:s_id=>nil/)))

      run_get users_url
    end

    it "logs all hash entries about the request" do
      api_basic_authorize

      expect($api_log).to receive(:info).with(
        a_string_matching(
          ":method.*:action.*:fullpath.*url.*:base.*:path.*:prefix.*:version.*:api_prefix.*:collection.*:c_suffix.*" \
          ":c_id.*:subcollection.*:s_id"
        )
      )

      run_get entrypoint_url
    end

    it "filters password attributes in nested parameters" do
      api_basic_authorize collection_action_identifier(:services, :create)

      expect($api_log).to receive(:info).with(
        a_string_matching(
          'Parameters:     {"action"=>"update", "controller"=>"api/services", "format"=>"json", ' \
          '"body"=>{"action"=>"create", "resource"=>{"name"=>"new_service_1", ' \
          '"options"=>{"password"=>"\[FILTERED\]"}}}}'
        )
      )

      run_post(services_url, gen_request(:create, "name" => "new_service_1", "options" => { "password" => "SECRET" }))
    end

    it "logs additional system authentication with miq_token" do
      Timecop.freeze("2017-01-01 00:00:00 UTC") do
        server_guid = MiqServer.first.guid
        userid = api_config(:user)
        timestamp = Time.now.utc

        miq_token = MiqPassword.encrypt({:server_guid => server_guid, :userid => userid, :timestamp => timestamp}.to_yaml)

        expect($api_log).to receive(:info).with(
          a_string_matching(
            "System Auth:    {:x_miq_token=>\"#{Regexp.escape(miq_token)}\", :server_guid=>\"#{server_guid}\", " \
            ":userid=>\"api_user_id\", :timestamp=>2017-01-01 00:00:00 UTC}"
          )
        )
        expect($api_log).to receive(:info).with(
          a_string_matching(
            'Authentication: {:type=>"system", :token=>nil, :x_miq_group=>nil, :user=>"api_user_id"}'
          )
        )

        run_get entrypoint_url, :headers => {Api::HttpHeaders::MIQ_TOKEN => miq_token}
      end
    end
  end
end

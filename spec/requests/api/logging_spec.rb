#
# REST API Logging Tests
#
describe "Logging" do
  describe "Successful Requests logging" do
    before do
      @log = StringIO.new
      $api_log.reopen(@log)
    end

    after { $api_log.reopen(Rails.root.join("log", "api.log")) }

    it "logs hashed details about the request" do
      api_basic_authorize collection_action_identifier(:users, :read, :get)

      run_get users_url

      @log.rewind
      expect(@log.readlines).to include(a_string_matching(/Request:/)
                                         .and(matching(%r{:path=>"/api/users"}))
                                         .and(matching(/:collection=>"users"/))
                                         .and(matching(/:c_id=>nil/))
                                         .and(matching(/:subcollection=>nil/))
                                         .and(matching(/:s_id=>nil/)))
    end

    it "logs all hash entries about the request" do
      api_basic_authorize

      run_get entrypoint_url

      @log.rewind
      expect(@log.readlines).to include(
        a_string_matching(
          ":method.*:action.*:fullpath.*url.*:base.*:path.*:prefix.*:version.*:api_prefix.*:collection.*:c_suffix.*" \
          ":c_id.*:subcollection.*:s_id"
        )
      )
    end

    it "filters password attributes in nested parameters" do
      api_basic_authorize collection_action_identifier(:services, :create)

      run_post(services_url, gen_request(:create, "name" => "new_service_1", "options" => { "password" => "SECRET" }))

      @log.rewind
      expect(@log.readlines).to include(
        a_string_matching(
          'Parameters:     {"action"=>"update", "controller"=>"api/services", "format"=>"json", ' \
          '"body"=>{"action"=>"create", "resource"=>{"name"=>"new_service_1", ' \
          '"options"=>{"password"=>"\[FILTERED\]"}}}}'
        )
      )
    end

    it "logs additional system authentication with miq_token" do
      Timecop.freeze("2017-01-01 00:00:00 UTC") do
        server_guid = MiqServer.first.guid
        userid = api_config(:user)
        timestamp = Time.now.utc

        miq_token = MiqPassword.encrypt({:server_guid => server_guid, :userid => userid, :timestamp => timestamp}.to_yaml)

        run_get entrypoint_url, :headers => {Api::HttpHeaders::MIQ_TOKEN => miq_token}

        @log.rewind
        expect(@log.readlines).to include(
          a_string_matching(
            "System Auth:    {:x_miq_token=>\"#{Regexp.escape(miq_token)}\", :server_guid=>\"#{server_guid}\", " \
            ":userid=>\"api_user_id\", :timestamp=>2017-01-01 00:00:00 UTC}"
          ),
          a_string_matching(
            'Authentication: {:type=>"system", :token=>nil, :x_miq_group=>nil, :user=>"api_user_id"}'
          )
        )
      end
    end
  end
end

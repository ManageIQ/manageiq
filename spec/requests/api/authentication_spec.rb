#
# REST API Request Tests - /api authentication
#
describe "Authentication API" do
  ENTRYPOINT_KEYS = %w(name description version versions identity collections)

  context "Basic Authentication" do
    it "test basic authentication with bad credentials" do
      basic_authorize "baduser", "badpassword"

      run_get entrypoint_url

      expect(response).to have_http_status(:unauthorized)
    end

    it "test basic authentication with correct credentials" do
      api_basic_authorize

      run_get entrypoint_url

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(ENTRYPOINT_KEYS)
    end

    it "test basic authentication with a user without a role" do
      @group.miq_user_role = nil
      @group.save

      api_basic_authorize

      run_get entrypoint_url

      expect(response).to have_http_status(:unauthorized)
    end

    it "test basic authentication with a user without a group" do
      @user.current_group = nil
      @user.save

      api_basic_authorize

      run_get entrypoint_url

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "Basic Authentication with Group Authorization" do
    let(:group1) { FactoryGirl.create(:miq_group, :description => "Group1", :miq_user_role => @role) }
    let(:group2) { FactoryGirl.create(:miq_group, :description => "Group2", :miq_user_role => @role) }

    before(:each) do
      @user.miq_groups = [group1, group2, @user.current_group]
      @user.current_group = group1
    end

    it "test basic authentication with incorrect group" do
      api_basic_authorize

      run_get entrypoint_url, :headers => {Api::HttpHeaders::MIQ_GROUP => "bogus_group"}

      expect(response).to have_http_status(:unauthorized)
    end

    it "test basic authentication with a primary group" do
      api_basic_authorize

      run_get entrypoint_url, :headers => {Api::HttpHeaders::MIQ_GROUP => group1.description}

      expect(response).to have_http_status(:ok)
    end

    it "test basic authentication with a secondary group" do
      api_basic_authorize

      run_get entrypoint_url, :headers => {Api::HttpHeaders::MIQ_GROUP => group2.description}

      expect(response).to have_http_status(:ok)
    end
  end

  context "Authentication/Authorization Identity" do
    let(:group1) { FactoryGirl.create(:miq_group, :description => "Group1", :miq_user_role => @role) }
    let(:group2) { FactoryGirl.create(:miq_group, :description => "Group2", :miq_user_role => @role) }

    before do
      @user.miq_groups = [group1, group2, @user.current_group]
      @user.current_group = group1
    end

    it "basic authentication with a secondary group" do
      api_basic_authorize

      run_get entrypoint_url, :headers => {Api::HttpHeaders::MIQ_GROUP => group2.description}

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(ENTRYPOINT_KEYS)
      expect_result_to_match_hash(
        response.parsed_body["identity"],
        "userid"     => @user.userid,
        "name"       => @user.name,
        "user_href"  => "/api/users/#{@user.id}",
        "group"      => group2.description,
        "group_href" => "/api/groups/#{group2.id}",
        "role"       => @role.name,
        "role_href"  => "/api/roles/#{group2.miq_user_role.id}",
        "tenant"     => @group.tenant.name
      )
      expect(response.parsed_body["identity"]["groups"]).to match_array(@user.miq_groups.pluck(:description))
    end

    it "querying user's authorization" do
      api_basic_authorize

      run_get entrypoint_url, :attributes => "authorization"

      expect(response).to have_http_status(:ok)
      expected = {"authorization" => hash_including("product_features")}
      ENTRYPOINT_KEYS.each { |k| expected[k] = anything }
      expect(response.parsed_body).to include(expected)
    end
  end

  context "Token Based Authentication" do
    it "gets a token based identifier" do
      api_basic_authorize

      run_get auth_url

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(auth_token token_ttl expires_on))
    end

    it "authentication using a bad token" do
      run_get entrypoint_url, :headers => {Api::HttpHeaders::AUTH_TOKEN => "badtoken"}

      expect(response).to have_http_status(:unauthorized)
    end

    it "authentication using a valid token" do
      api_basic_authorize

      run_get auth_url

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(auth_token))

      auth_token = response.parsed_body["auth_token"]

      run_get entrypoint_url, :headers => {Api::HttpHeaders::AUTH_TOKEN => auth_token}

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(ENTRYPOINT_KEYS)
    end

    it "authentication using a valid token updates the token's expiration time" do
      api_basic_authorize

      run_get auth_url

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(auth_token token_ttl expires_on))

      auth_token = response.parsed_body["auth_token"]
      token_expires_on = response.parsed_body["expires_on"]

      tm = TokenManager.new("api")
      token_info = tm.token_get_info(auth_token)
      expect(token_info[:expires_on].utc.iso8601).to eq(token_expires_on)

      expect_any_instance_of(TokenManager).to receive(:reset_token).with(auth_token)
      run_get entrypoint_url, :headers => {Api::HttpHeaders::AUTH_TOKEN => auth_token}

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(ENTRYPOINT_KEYS)
    end

    it "gets a token based identifier with the default API based token_ttl" do
      api_basic_authorize
      run_get auth_url

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(auth_token token_ttl expires_on))
      expect(response.parsed_body["token_ttl"]).to eq(::Settings.api.token_ttl.to_i_with_method)
    end

    it "gets a token based identifier with an invalid requester_type" do
      api_basic_authorize

      run_get auth_url, :requester_type => "bogus_type"

      expect_bad_request(/invalid requester_type/i)
    end

    it "gets a token based identifier with a UI based token_ttl" do
      api_basic_authorize

      run_get auth_url, :requester_type => "ui"

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(auth_token token_ttl expires_on))
      expect(response.parsed_body["token_ttl"]).to eq(::Settings.session.timeout.to_i_with_method)
    end

    it "forgets the current token when asked to" do
      api_basic_authorize

      run_get auth_url

      auth_token = response.parsed_body["auth_token"]

      expect_any_instance_of(TokenManager).to receive(:invalidate_token).with(auth_token)
      run_delete auth_url, Api::HttpHeaders::AUTH_TOKEN => auth_token
    end

    context 'Tokens for Web Sockets' do
      it 'gets a UI based token_ttl when requesting token for web sockets' do
        api_basic_authorize

        run_get auth_url, :requester_type => 'ws'
        expect(response).to have_http_status(:ok)
        expect_result_to_have_keys(%w(auth_token token_ttl expires_on))
        expect(response.parsed_body["token_ttl"]).to eq(::Settings.session.timeout.to_i_with_method)
      end

      it 'cannot authorize user to api based on token that is dedicated for web sockets' do
        api_basic_authorize
        run_get auth_url, :requester_type => 'ws'
        ws_token = response.parsed_body["auth_token"]

        run_get entrypoint_url, :headers => {Api::HttpHeaders::AUTH_TOKEN => ws_token}

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  context "System Token Based Authentication" do
    AUTHENTICATION_ERROR = "Invalid System Authentication Token specified".freeze

    def systoken(server_guid, userid, timestamp)
      MiqPassword.encrypt({:server_guid => server_guid, :userid => userid, :timestamp => timestamp}.to_yaml)
    end

    it "authentication using a bad token" do
      run_get entrypoint_url,
              :headers => {Api::HttpHeaders::MIQ_TOKEN => "badtoken"}

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include(
        "error" => a_hash_including("kind" => "unauthorized", "message" => AUTHENTICATION_ERROR)
      )
    end

    it "authentication using a token with a bad server guid" do
      run_get entrypoint_url,
              :headers => {Api::HttpHeaders::MIQ_TOKEN => systoken("bad_server_guid", api_config(:user), Time.now.utc)}

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include(
        "error" => a_hash_including("kind" => "unauthorized", "message" => AUTHENTICATION_ERROR)
      )
    end

    it "authentication using a token with bad user" do
      run_get entrypoint_url,
              :headers => {Api::HttpHeaders::MIQ_TOKEN => systoken(MiqServer.first.guid, "bad_user_id", Time.now.utc)}

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include(
        "error" => a_hash_including("kind" => "unauthorized", "message" => AUTHENTICATION_ERROR)
      )
    end

    it "authentication using a token with an old timestamp" do
      miq_token = systoken(MiqServer.first.guid, api_config(:user), 10.minutes.ago.utc)

      run_get entrypoint_url, :headers => {Api::HttpHeaders::MIQ_TOKEN => miq_token}

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include(
        "error" => a_hash_including("kind" => "unauthorized", "message" => AUTHENTICATION_ERROR)
      )
    end

    it "authentication using a valid token succeeds" do
      miq_token = systoken(MiqServer.first.guid, api_config(:user), Time.now.utc)

      run_get entrypoint_url, :headers => {Api::HttpHeaders::MIQ_TOKEN => miq_token}

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(ENTRYPOINT_KEYS)
    end
  end

  context "Role Based Authorization" do
    before do
      FactoryGirl.create(:vm_vmware, :name => "vm1")
    end

    context "actions with single role identifier" do
      it "are rejected when user is not authorized with the single role identifier" do
        stub_api_action_role(:vms, :collection_actions, :get, :read, "vm_view_role1")
        api_basic_authorize

        run_get vms_url

        expect(response).to have_http_status(:forbidden)
      end

      it "are accepted when user is authorized with the single role identifier" do
        stub_api_action_role(:vms, :collection_actions, :get, :read, "vm_view_role1")
        api_basic_authorize "vm_view_role1"

        run_get vms_url

        expect_query_result(:vms, 1, 1)
      end
    end

    context "actions with multiple role identifiers" do
      it "are rejected when user is not authorized with any of the role identifiers" do
        stub_api_action_role(:vms, :collection_actions, :get, :read, %w(vm_view_role1 vm_view_role2))
        api_basic_authorize

        run_get vms_url

        expect(response).to have_http_status(:forbidden)
      end

      it "are accepted when user is authorized with at least one of the role identifiers" do
        stub_api_action_role(:vms, :collection_actions, :get, :read, %w(vm_view_role1 vm_view_role2))
        api_basic_authorize "vm_view_role2"

        run_get vms_url

        expect_query_result(:vms, 1, 1)
      end
    end
  end
end

#
# REST API Request Tests - /api authentication
#
describe ApiController do
  ENTRYPOINT_KEYS = %w(name description version versions identity collections)

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
      expect_result_to_have_keys(ENTRYPOINT_KEYS)
    end

    it "test basic authentication with a user without a role" do
      @group.miq_user_role = nil
      @group.save

      api_basic_authorize

      run_get entrypoint_url

      expect_user_unauthorized
    end

    it "test basic authentication with a user without a group" do
      @user.current_group = nil
      @user.save

      api_basic_authorize

      run_get entrypoint_url

      expect_user_unauthorized
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

      run_get entrypoint_url, :headers => {"miq_group" => "bogus_group"}

      expect_user_unauthorized
    end

    it "test basic authentication with a primary group" do
      api_basic_authorize

      run_get entrypoint_url, :headers => {"miq_group" => group1.description}

      expect_single_resource_query
    end

    it "test basic authentication with a secondary group" do
      api_basic_authorize

      run_get entrypoint_url, :headers => {"miq_group" => group2.description}

      expect_single_resource_query
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

      run_get entrypoint_url, :headers => {"miq_group" => group2.description}

      expect_single_resource_query
      expect_result_to_have_keys(ENTRYPOINT_KEYS)
      expect_result_to_match_hash(
        response_hash["identity"],
        "userid"     => @user.userid,
        "name"       => @user.name,
        "user_href"  => "/api/users/#{@user.id}",
        "group"      => group2.description,
        "group_href" => "/api/groups/#{group2.id}",
        "role"       => @role.name,
        "role_href"  => "/api/roles/#{group2.miq_user_role.id}",
        "tenant"     => @group.tenant.name
      )
      expect(response_hash["identity"]["groups"]).to match_array(@user.miq_groups.pluck(:description))
    end

    it "querying user's authorization" do
      api_basic_authorize

      run_get entrypoint_url, :attributes => "authorization"

      expect_single_resource_query
      expect_result_to_have_keys(ENTRYPOINT_KEYS + %w(authorization))
      expect_hash_to_have_keys(response_hash["authorization"], %w(product_features))
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

      auth_token = response_hash["auth_token"]

      run_get entrypoint_url, :headers => {"auth_token" => auth_token}

      expect_single_resource_query
      expect_result_to_have_keys(ENTRYPOINT_KEYS)
    end

    it "authentication using a valid token updates the token's expiration time" do
      api_basic_authorize

      run_get auth_url

      expect_single_resource_query
      expect_result_to_have_keys(%w(auth_token token_ttl expires_on))

      auth_token = response_hash["auth_token"]
      token_expires_on = response_hash["expires_on"]

      tm = TokenManager.new("api")
      token_info = tm.token_get_info("api", auth_token)
      expect(token_info[:expires_on].utc.iso8601).to eq(token_expires_on)

      expect_any_instance_of(TokenManager).to receive(:reset_token).with("api", auth_token)
      run_get entrypoint_url, :headers => {"auth_token" => auth_token}

      expect_single_resource_query
      expect_result_to_have_keys(ENTRYPOINT_KEYS)
    end

    it "gets a token based identifier with the default API based token_ttl" do
      api_basic_authorize

      api_token_ttl = VMDB::Config.new("vmdb").config[:api][:token_ttl].to_i_with_method
      run_get auth_url

      expect_single_resource_query
      expect_result_to_have_keys(%w(auth_token token_ttl expires_on))
      expect(response_hash["token_ttl"]).to eq(api_token_ttl)
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
      expect(response_hash["token_ttl"]).to eq(ui_token_ttl)
    end

    it "forgets the current token when asked to" do
      api_basic_authorize

      run_get auth_url

      auth_token = response_hash["auth_token"]

      expect_any_instance_of(TokenManager).to receive(:invalidate_token).with("api", auth_token)
      run_delete auth_url, "auth_token" => auth_token
    end
  end
end

#
# REST API Request Tests - /api/settings
#
describe "Settings API" do
  let(:api_settings) { Api::ApiConfig.collections[:settings][:categories] }

  context "Settings Queries" do
    it "tests queries of all exposed settings" do
      api_basic_authorize action_identifier(:settings, :read, :collection_actions, :get)

      run_get settings_url

      expect_result_to_have_only_keys(api_settings)
    end

    it "tests query for a specific setting category" do
      api_basic_authorize action_identifier(:settings, :read, :resource_actions, :get)

      category = api_settings.first
      run_get settings_url(category)

      expect_result_to_have_only_keys(category)
    end

    it "tests that query for a specific setting category matches the Settings hash" do
      api_basic_authorize action_identifier(:settings, :read, :resource_actions, :get)

      category = api_settings.first
      run_get settings_url(category)

      expect(response.parsed_body[category]).to eq(Settings[category].to_hash.stringify_keys)
    end

    it "rejects query for an invalid setting category " do
      api_basic_authorize action_identifier(:settings, :read, :resource_actions, :get)

      run_get settings_url("invalid_setting")

      expect(response).to have_http_status(:not_found)
    end
  end
end

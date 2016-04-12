#
# REST API Request Tests - /api/settings
#
describe ApiController do
  let(:api_settings_config_file) { Rails.root.join("config/api_settings.yml") }
  let(:api_settings)             { YAML.load_file(api_settings_config_file)[:settings] }

  context "Settings Queries" do
    it "tests queries of all exposed settings" do
      api_basic_authorize

      run_get settings_url

      expect_result_to_have_only_keys(api_settings)
    end

    it "tests query for a specific setting category" do
      api_basic_authorize

      category = api_settings.first
      run_get settings_url(category)

      expect_result_to_have_only_keys(category)
    end

    it "tests that query for a specific setting category matches the Settings hash" do
      api_basic_authorize

      category = api_settings.first
      run_get settings_url(category)

      expect(response_hash[category]).to eq(Settings[category].to_hash.stringify_keys)
    end

    it "rejects query for an invalid setting category " do
      api_basic_authorize

      run_get settings_url("invalid_setting")

      expect_resource_not_found
    end
  end
end

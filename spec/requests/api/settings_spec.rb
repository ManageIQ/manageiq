#
# REST API Request Tests - /api/settings
#
describe "Settings API" do
  let(:api_settings) { Api::ApiConfig.collections[:settings][:categories] }

  def normalize_settings(settings)
    normalize_hash(settings.to_hash.deep_stringify_keys)
  end

  def normalize_hash(settings)
    settings.keys.each_with_object({}) do |key, hash|
      value = settings[key]
      new_value = case value
                  when Hash   then normalize_hash(value)
                  when Symbol then value.to_s
                  else value
                  end
      hash[key] = new_value unless new_value.nil?
    end
  end

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

    it "supports multiple categories" do
      stub_api_collection_config("settings", "categories", %w(product authentication server))
      api_basic_authorize action_identifier(:settings, :read, :resource_actions, :get)

      run_get settings_url

      expect(response.parsed_body).to match(
        "product"        => normalize_settings(Settings.product),
        "authentication" => normalize_settings(Settings.authentication),
        "server"         => normalize_settings(Settings.server)
      )
    end

    it "supports partial categories" do
      stub_api_collection_config("settings", "categories", %w(product server/role))
      api_basic_authorize action_identifier(:settings, :read, :resource_actions, :get)

      run_get settings_url

      expect(response.parsed_body).to match(
        "product" => normalize_settings(Settings.product),
        "server"  => { "role" => Settings.server.role }
      )
    end

    it "supports second level partial categories" do
      stub_api_collection_config("settings", "categories", %w(product server/role server/worker_monitor/sync_interval))
      api_basic_authorize action_identifier(:settings, :read, :resource_actions, :get)

      run_get settings_url

      expect(response.parsed_body).to match(
        "product" => normalize_settings(Settings.product),
        "server"  => {
          "role"           => Settings.server.role,
          "worker_monitor" => { "sync_interval" => Settings.server.worker_monitor.sync_interval }
        }
      )
    end

    it "supports multiple and partial categories" do
      stub_api_collection_config("settings", "categories", %w(product server/role server/worker_monitor authentication))
      api_basic_authorize action_identifier(:settings, :read, :resource_actions, :get)

      run_get settings_url

      expect(response.parsed_body).to match(
        "product"        => normalize_settings(Settings.product),
        "server"         => {
          "role"           => Settings.server.role,
          "worker_monitor" => normalize_settings(Settings.server.worker_monitor),
        },
        "authentication" => normalize_settings(Settings.authentication)
      )
    end
  end
end

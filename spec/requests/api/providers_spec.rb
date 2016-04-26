#
# Rest API Request Tests - Providers specs
#
# - Creating a provider                   /api/providers                        POST
# - Creating a provider via action        /api/providers                        action "create"
# - Creating multiple providers           /api/providers                        action "create"
# - Edit a provider                       /api/providers/:id                    action "edit"
# - Edit multiple providers               /api/providers                        action "edit"
# - Delete a provider                     /api/providers/:id                    DELETE
# - Delete a provider by action           /api/providers/:id                    action "delete"
# - Delete multiple providers             /api/providers                        action "delete"
#
# - Refresh a provider                    /api/providers/:id                    action "refresh"
# - Refresh multiple providers            /api/providers                        action "refresh"
#
describe ApiController do
  ENDPOINT_ATTRS = ApiController::Providers::ENDPOINT_ATTRS

  let(:default_credentials) { {"userid" => "admin1", "password" => "password1"} }
  let(:metrics_credentials) { {"userid" => "admin2", "password" => "password2", "auth_type" => "metrics"} }
  let(:compound_credentials) { [default_credentials, metrics_credentials] }
  let(:openshift_credentials) do
    {
      "auth_type" => "bearer",
      "auth_key"  => SecureRandom.hex
    }
  end
  let(:sample_vmware) do
    {
      "type"      => "ManageIQ::Providers::Vmware::InfraManager",
      "name"      => "sample vmware",
      "hostname"  => "sample_vmware.provider.com",
      "ipaddress" => "100.200.300.1"
    }
  end
  let(:sample_rhevm) do
    {
      "type"      => "ManageIQ::Providers::Redhat::InfraManager",
      "name"      => "sample rhevm",
      "port"      => 5000,
      "hostname"  => "sample_rhevm.provider.com",
      "ipaddress" => "100.200.300.2"
    }
  end
  let(:sample_openshift) do
    {
      "type"      => "ManageIQ::Providers::Openshift::ContainerManager",
      "name"      => "sample openshift",
      "port"      => "8443",
      "hostname"  => "sample_openshift.provider.com",
      "ipaddress" => "100.200.300.3",
    }
  end

  describe "Providers actions on Provider class" do
    it "rejects requests with invalid provider_class" do
      api_basic_authorize

      run_get providers_url, :provider_class => "bad_class"

      expect_bad_request(/unsupported/i)
    end

    it "supports requests with valid provider_class" do
      api_basic_authorize

      FactoryGirl.build(:provider_foreman)
      run_get providers_url, :provider_class => "provider", :expand => "resources"

      klass = Provider
      expect_query_result(:providers, klass.count, klass.count)
      expect_result_resources_to_include_data("resources", "name" => klass.pluck(:name))
    end
  end

  describe "Providers create" do
    it "rejects creation without appropriate role" do
      api_basic_authorize

      run_post(providers_url, sample_rhevm)

      expect_request_forbidden
    end

    it "rejects provider creation with id specified" do
      api_basic_authorize collection_action_identifier(:providers, :create)

      run_post(providers_url, "name" => "sample provider", "id" => 100)

      expect_bad_request(/id or href should not be specified/i)
    end

    it "rejects provider creation with invalid type specified" do
      api_basic_authorize collection_action_identifier(:providers, :create)

      run_post(providers_url, "name" => "sample provider", "type" => "BogusType")

      expect_bad_request(/Invalid provider type BogusType/i)
    end

    it "supports single provider creation" do
      api_basic_authorize collection_action_identifier(:providers, :create)

      run_post(providers_url, sample_rhevm)

      expect_request_success
      expect_result_resource_keys_to_be_like_klass("results", "id", Integer)
      expect_results_to_match_hash("results", [sample_rhevm.except(*ENDPOINT_ATTRS)])

      provider_id = response_hash["results"].first["id"]
      expect(ExtManagementSystem.exists?(provider_id)).to be_truthy
      endpoint = ExtManagementSystem.find(provider_id).default_endpoint
      expect_result_to_match_hash(endpoint.attributes, sample_rhevm.slice(*ENDPOINT_ATTRS))
    end

    it "supports openshift creation with auth_key specified" do
      api_basic_authorize collection_action_identifier(:providers, :create)

      run_post(providers_url, sample_openshift.merge("credentials" => [openshift_credentials]))

      expect_request_success
      expect_result_resource_keys_to_be_like_klass("results", "id", Integer)
      expect_results_to_match_hash("results", [sample_openshift.except(*ENDPOINT_ATTRS)])

      provider_id = response_hash["results"].first["id"]
      expect(ExtManagementSystem.exists?(provider_id)).to be_truthy
      expect(ExtManagementSystem.find(provider_id).authentications.size).to eq(1)
    end

    it "supports single provider creation via action" do
      api_basic_authorize collection_action_identifier(:providers, :create)

      run_post(providers_url, gen_request(:create, sample_rhevm))

      expect_request_success
      expect_result_resource_keys_to_be_like_klass("results", "id", Integer)
      expect_results_to_match_hash("results", [sample_rhevm.except(*ENDPOINT_ATTRS)])

      provider_id = response_hash["results"].first["id"]
      expect(ExtManagementSystem.exists?(provider_id)).to be_truthy
    end

    it "supports single provider creation with simple credentials" do
      api_basic_authorize collection_action_identifier(:providers, :create)

      run_post(providers_url, sample_vmware.merge("credentials" => default_credentials))

      expect_request_success
      expect_result_resource_keys_to_be_like_klass("results", "id", Integer)
      expect_results_to_match_hash("results", [sample_vmware.except(*ENDPOINT_ATTRS)])

      provider_id = response_hash["results"].first["id"]
      expect(ExtManagementSystem.exists?(provider_id)).to be_truthy
      provider = ExtManagementSystem.find(provider_id)
      expect(provider.authentication_userid).to eq(default_credentials["userid"])
      expect(provider.authentication_password).to eq(default_credentials["password"])
    end

    it "supports single provider creation with compound credentials" do
      api_basic_authorize collection_action_identifier(:providers, :create)

      run_post(providers_url, sample_rhevm.merge("credentials" => compound_credentials))

      expect_request_success
      expect_result_resource_keys_to_be_like_klass("results", "id", Integer)
      expect_results_to_match_hash("results", [sample_rhevm.except(*ENDPOINT_ATTRS)])

      provider_id = response_hash["results"].first["id"]
      expect(ExtManagementSystem.exists?(provider_id)).to be_truthy
      provider = ExtManagementSystem.find(provider_id)
      expect(provider.authentication_userid(:default)).to eq(default_credentials["userid"])
      expect(provider.authentication_password(:default)).to eq(default_credentials["password"])
      expect(provider.authentication_userid(:metrics)).to eq(metrics_credentials["userid"])
      expect(provider.authentication_password(:metrics)).to eq(metrics_credentials["password"])
    end

    it "supports multiple provider creation" do
      api_basic_authorize collection_action_identifier(:providers, :create)

      run_post(providers_url, gen_request(:create, [sample_vmware, sample_rhevm]))

      expect_request_success
      expect_result_resource_keys_to_be_like_klass("results", "id", Integer)
      expect_results_to_match_hash("results",
                                   [sample_vmware.except(*ENDPOINT_ATTRS), sample_rhevm.except(*ENDPOINT_ATTRS)])

      results = response_hash["results"]
      p1_id, p2_id = results.first["id"], results.second["id"]
      expect(ExtManagementSystem.exists?(p1_id)).to be_truthy
      expect(ExtManagementSystem.exists?(p2_id)).to be_truthy
    end
  end

  describe "Providers edit" do
    it "rejects resource edits without appropriate role" do
      api_basic_authorize

      run_post(providers_url, gen_request(:edit, "name" => "provider name", "href" => providers_url(999_999)))

      expect_request_forbidden
    end

    it "rejects edits for invalid resources" do
      api_basic_authorize collection_action_identifier(:providers, :edit)

      run_post(providers_url(999_999), gen_request(:edit, "name" => "updated provider name"))

      expect_resource_not_found
    end

    it "supports single resource edit" do
      api_basic_authorize collection_action_identifier(:providers, :edit)

      provider = FactoryGirl.create(:ext_management_system, sample_rhevm)

      run_post(providers_url(provider.id), gen_request(:edit, "name" => "updated provider", "port" => "8080"))

      expect_single_resource_query("id" => provider.id, "name" => "updated provider")
      expect(provider.reload.name).to eq("updated provider")
      expect(provider.port).to eq(8080)
    end

    it "supports updates of credentials" do
      api_basic_authorize collection_action_identifier(:providers, :edit)

      provider = FactoryGirl.create(:ext_management_system, sample_vmware)
      provider.update_authentication(:default => default_credentials.symbolize_keys)

      run_post(providers_url(provider.id), gen_request(:edit,
                                                       "name"        => "updated vmware",
                                                       "credentials" => {"userid" => "superadmin"}))

      expect_single_resource_query("id" => provider.id, "name" => "updated vmware")
      expect(provider.reload.name).to eq("updated vmware")
      expect(provider.authentication_userid).to eq("superadmin")
    end

    it "supports additions of credentials" do
      api_basic_authorize collection_action_identifier(:providers, :edit)

      provider = FactoryGirl.create(:ext_management_system, sample_rhevm)
      provider.update_authentication(:default => default_credentials.symbolize_keys)

      run_post(providers_url(provider.id), gen_request(:edit,
                                                       "name"        => "updated rhevm",
                                                       "credentials" => [metrics_credentials]))

      expect_single_resource_query("id" => provider.id, "name" => "updated rhevm")
      expect(provider.reload.name).to eq("updated rhevm")
      expect(provider.authentication_userid).to eq(default_credentials["userid"])
      expect(provider.authentication_userid(:metrics)).to eq(metrics_credentials["userid"])
    end

    it "supports multiple resource edits" do
      api_basic_authorize collection_action_identifier(:providers, :edit)

      p1 = FactoryGirl.create(:ems_redhat, :name => "name1")
      p2 = FactoryGirl.create(:ems_redhat, :name => "name2")

      run_post(providers_url, gen_request(:edit,
                                          [{"href" => providers_url(p1.id), "name" => "updated name1"},
                                           {"href" => providers_url(p2.id), "name" => "updated name2"}]))

      expect_results_to_match_hash("results",
                                   [{"id" => p1.id, "name" => "updated name1"},
                                    {"id" => p2.id, "name" => "updated name2"}])

      expect(p1.reload.name).to eq("updated name1")
      expect(p2.reload.name).to eq("updated name2")
    end
  end

  describe "Providers delete" do
    it "rejects deletion without appropriate role" do
      api_basic_authorize

      run_post(providers_url, gen_request(:delete, "name" => "provider name", "href" => providers_url(100)))

      expect_request_forbidden
    end

    it "rejects deletion without appropriate role" do
      api_basic_authorize

      run_delete(providers_url(100))

      expect_request_forbidden
    end

    it "rejects deletes for invalid providers" do
      api_basic_authorize collection_action_identifier(:providers, :delete)

      run_delete(providers_url(999_999))

      expect_resource_not_found
    end

    it "supports single provider delete" do
      api_basic_authorize collection_action_identifier(:providers, :delete)

      provider = FactoryGirl.create(:ext_management_system, :name => "provider", :hostname => "provider.com")

      run_delete(providers_url(provider.id))

      expect_request_success_with_no_content
    end

    it "supports single provider delete action" do
      api_basic_authorize collection_action_identifier(:providers, :delete)

      provider = FactoryGirl.create(:ext_management_system, :name => "provider", :hostname => "provider.com")

      run_post(providers_url(provider.id), gen_request(:delete))

      expect_single_action_result(:success => true,
                                  :message => "deleting",
                                  :href    => providers_url(provider.id),
                                  :task    => true)
    end

    it "supports multiple provider deletes" do
      api_basic_authorize collection_action_identifier(:providers, :delete)

      p1 = FactoryGirl.create(:ext_management_system, :name => "provider name 1")
      p2 = FactoryGirl.create(:ext_management_system, :name => "provider name 2")

      run_post(providers_url, gen_request(:delete,
                                          [{"href" => providers_url(p1.id)},
                                           {"href" => providers_url(p2.id)}]))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", [providers_url(p1.id), providers_url(p2.id)])
    end
  end

  describe "Providers refresh" do
    def failed_auth_action(id)
      {"success" => false, "message" => /failed last authentication check/i, "href" => providers_url(id)}
    end

    it "rejects refresh requests without appropriate role" do
      api_basic_authorize

      run_post(providers_url(100), gen_request(:refresh))

      expect_request_forbidden
    end

    it "supports single provider refresh" do
      api_basic_authorize collection_action_identifier(:providers, :refresh)

      provider = FactoryGirl.create(:ext_management_system, sample_vmware.symbolize_keys.except(:type))
      provider.update_authentication(:default => default_credentials.symbolize_keys)

      run_post(providers_url(provider.id), gen_request(:refresh))

      expect_single_action_result(failed_auth_action(provider.id).symbolize_keys)
    end

    it "supports multiple provider refreshes" do
      api_basic_authorize collection_action_identifier(:providers, :refresh)

      p1 = FactoryGirl.create(:ext_management_system, sample_vmware.symbolize_keys.except(:type))
      p1.update_authentication(:default => default_credentials.symbolize_keys)

      p2 = FactoryGirl.create(:ext_management_system, sample_rhevm.symbolize_keys.except(:type))
      p2.update_authentication(:default => default_credentials.symbolize_keys)

      run_post(providers_url, gen_request(:refresh, [{"href" => providers_url(p1.id)},
                                                     {"href" => providers_url(p2.id)}]))
      expect_request_success
      expect_results_to_match_hash("results", [failed_auth_action(p1.id), failed_auth_action(p2.id)])
    end
  end
end

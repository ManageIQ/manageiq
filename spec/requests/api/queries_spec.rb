#
# REST API Request Tests - Queries
#
describe ApiController do
  let(:zone)       { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server) { FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => zone) }
  let(:ems)        { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)       { FactoryGirl.create(:host) }

  let(:vm1)        { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm1_url)    { vms_url(vm1.id) }

  let(:vm_href_pattern) { %r{^http://.*/api/vms/[0-9]+$} }

  def create_vms(count)
    count.times { FactoryGirl.create(:vm_vmware) }
  end

  describe "Query collections" do
    it "returns resource lists with only hrefs" do
      api_basic_authorize
      create_vms(3)

      run_get vms_url

      expect_query_result(:vms, 3, 3)
      expect_result_resources_to_have_only_keys("resources", %w(href))
      expect_result_resource_keys_to_match_pattern("resources", "href", :vm_href_pattern)
    end

    it "returns seperate ids and href when expanded" do
      api_basic_authorize
      create_vms(3)

      run_get vms_url, :expand => "resources"

      expect_query_result(:vms, 3, 3)
      expect_result_resource_keys_to_match_pattern("resources", "href", :vm_href_pattern)
      expect_result_resource_keys_to_be_like_klass("resources", "id", Integer)
      expect_result_resources_to_include_keys("resources", %w(guid))
    end

    it "always return ids and href when asking for specific attributes" do
      api_basic_authorize
      vm1   # create resource

      run_get vms_url, :expand => "resources", :attributes => "guid"

      expect_query_result(:vms, 1, 1)
      expect_result_resources_to_match_hash([{"id" => vm1.id, "href" => vm1_url, "guid" => vm1.guid}])
    end
  end

  describe "Query resource" do
    it "returns both id and href" do
      api_basic_authorize
      vm1   # create resource

      run_get vm1_url

      expect_single_resource_query("id" => vm1.id, "href" => vm1_url, "guid" => vm1.guid)
    end
  end

  describe "Query subcollections" do
    let(:acct1) { FactoryGirl.create(:account, :vm_or_template_id => vm1.id, :name => "John") }
    let(:acct2) { FactoryGirl.create(:account, :vm_or_template_id => vm1.id, :name => "Jane") }
    let(:vm1_accounts_url) { "#{vm1_url}/accounts" }
    let(:acct1_url)        { "#{vm1_accounts_url}/#{acct1.id}" }
    let(:acct2_url)        { "#{vm1_accounts_url}/#{acct2.id}" }
    let(:vm1_accounts_url_list) { [acct1_url, acct2_url] }

    it "returns just href when not expanded" do
      api_basic_authorize
      # create resources
      acct1
      acct2

      run_get vm1_accounts_url

      expect_query_result(:accounts, 2)
      expect_result_resources_to_include_hrefs("resources", :vm1_accounts_url_list)
    end

    it "includes both id and href when getting a single resource" do
      api_basic_authorize

      run_get acct1_url

      expect_single_resource_query("id" => acct1.id, "href" => acct1_url, "name" => acct1.name)
    end

    it "includes both id and href when expanded" do
      api_basic_authorize
      # create resources
      acct1
      acct2

      run_get vm1_accounts_url, :expand => "resources"

      expect_query_result(:accounts, 2)
      expect_result_resources_to_include_keys("resources", %w(id href))
      expect_result_resources_to_include_hrefs("resources", :vm1_accounts_url_list)
      expect_result_resources_to_include_data("resources", "id" => [acct1.id, acct2.id])
    end
  end

  describe "Querying encrypted attributes" do
    it "hides them from database records" do
      api_basic_authorize

      credentials = {:userid => "admin", :password => "super_password"}

      provider = FactoryGirl.create(:ext_management_system, :name => "sample", :hostname => "sample.com")
      provider.update_authentication(:default => credentials)

      run_get(providers_url(provider.id), :attributes => "authentications")

      expect_request_success
      expect_result_to_match_hash(@result, "name" => "sample")
      expect_result_to_have_keys(%w(authentications))
      authentication = @result["authentications"].first
      expect(authentication["userid"]).to eq("admin")
      expect(authentication.key?("password")).to be_falsey
    end

    it "hides them from configuration hashes" do
      api_basic_authorize

      password_field = ::Vmdb::ConfigurationEncoder::PASSWORD_FIELDS.last.to_s
      config = {:authentication => {:userid => "admin", password_field.to_sym => "super_password"}}

      Configuration.create_or_update(miq_server, config, "authentications")

      run_get(servers_url(miq_server.id), :attributes => "configurations")

      expect_request_success
      expect_result_to_have_keys(%w(configurations))
      configuration = @result["configurations"].first
      authentication = configuration.fetch_path("settings", "authentication")
      expect(authentication).to_not be_nil
      expect(authentication["userid"]).to eq("admin")
      expect(authentication.key?(password_field)).to be_falsey
    end

    it "hides them from provisioning hashes" do
      api_basic_authorize

      password_field = ::MiqRequestWorkflow.all_encrypted_options_fields.last.to_s
      options = {:attrs => {:userid => "admin", password_field.to_sym => "super_password"}}

      template = FactoryGirl.create(:template_vmware, :name => "template1")
      request  = FactoryGirl.create(:miq_provision_request,
                                    :requester   => @user,
                                    :description => "sample provision",
                                    :src_vm_id   => template.id,
                                    :options     => options)

      run_get provision_requests_url(request.id)

      expect_request_success
      expect_result_to_match_hash(@result, "description" => "sample provision")
      provision_attrs = @result.fetch_path("options", "attrs")
      expect(provision_attrs).to_not be_nil
      expect(provision_attrs["userid"]).to eq("admin")
      expect(provision_attrs.key?(password_field)).to be_falsey
    end
  end
end

#
# Rest API Request Tests - Provision Requests specs
#
# - Create single provision request    /api/provision_requests    normal POST
# - Create single provision request    /api/provision_requests    action "create"
# - Create multiple provision requests /api/provision_requests    action "create"
#
describe ApiController do
  let(:zone)       { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server) { FactoryGirl.create(:miq_server, :zone => zone) }
  let(:ems)        { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)       { FactoryGirl.create(:host, :ext_management_system => ems) }
  let(:dialog)     { FactoryGirl.create(:miq_dialog_provision) }

  describe "Provision Requests" do
    let(:hardware) { FactoryGirl.create(:hardware, :memory_mb => 1024) }
    let(:template) do
      FactoryGirl.create(:template_vmware,
                         :name                  => "template1",
                         :host                  => host,
                         :ext_management_system => ems,
                         :hardware              => hardware)
    end

    let(:single_provision_request) do
      {
        "template_fields" => {"guid" => template.guid},
        "vm_fields"       => {"number_of_cpus" => 1, "vm_name" => "api_test"},
        "requester"       => {"user_name" => api_config(:user)}
      }
    end

    let(:expected_attributes) { %w(id options) }
    let(:expected_hash) do
      {
        "userid"         => api_config(:user),
        "requester_name" => api_config(:user_name),
        "approval_state" => "pending_approval",
        "type"           => "MiqProvisionRequest",
        "request_type"   => "template",
        "message"        => /Provisioning/i,
        "status"         => "Ok"
      }
    end

    it "rejects requests without appropriate role" do
      api_basic_authorize

      run_post(provision_requests_url, single_provision_request)

      expect_request_forbidden
    end

    it "supports single request with normal post" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      dialog  # Create the Provisioning dialog
      run_post(provision_requests_url, single_provision_request)

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)
      expect_results_to_match_hash("results", [expected_hash])

      task_id = response_hash["results"].first["id"]
      expect(MiqProvisionRequest.exists?(task_id)).to be_truthy
    end

    it "supports single request with create action" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      dialog  # Create the Provisioning dialog
      run_post(provision_requests_url, gen_request(:create, single_provision_request))

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)
      expect_results_to_match_hash("results", [expected_hash])

      task_id = response_hash["results"].first["id"]
      expect(MiqProvisionRequest.exists?(task_id)).to be_truthy
    end

    it "supports multiple requests" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      dialog  # Create the Provisioning dialog
      run_post(provision_requests_url, gen_request(:create, [single_provision_request, single_provision_request]))

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)
      expect_results_to_match_hash("results", [expected_hash, expected_hash])

      task_id1, task_id2 = response_hash["results"].collect { |r| r["id"] }
      expect(MiqProvisionRequest.exists?(task_id1)).to be_truthy
      expect(MiqProvisionRequest.exists?(task_id2)).to be_truthy
    end
  end

  context "AWS advanced provision requests" do
    let!(:aws_dialog) do
      path = Rails.root.join("product", "dialogs", "miq_dialogs", "miq_provision_amazon_dialogs_template.yaml")
      content = YAML.load_file(path)[:content]
      dialog = FactoryGirl.create(:miq_dialog, :name => "miq_provision_amazon_dialogs_template",
                                  :dialog_type => "MiqProvisionWorkflow", :content => content)
      allow_any_instance_of(MiqRequestWorkflow).to receive(:dialog_name_from_automate).and_return(dialog.name)
    end
    let(:ems) { FactoryGirl.create(:ems_amazon_with_authentication) }
    let(:template) do
      FactoryGirl.create(:template_amazon, :name => "template1", :ext_management_system => ems)
    end
    let(:flavor) do
      FactoryGirl.create(:flavor_amazon, :ems_id => ems.id, :name => 't2.small', :cloud_subnet_required => true)
    end
    let(:az)             { FactoryGirl.create(:availability_zone_amazon, :ems_id => ems.id) }
    let(:cloud_network1) { FactoryGirl.create(:cloud_network_amazon, :ems_id => ems.network_manager.id, :enabled => true) }
    let(:cloud_subnet1) do
      FactoryGirl.create(:cloud_subnet, :ems_id => ems.id, :cloud_network => cloud_network1, :availability_zone => az)
    end
    let(:security_group1) do
      FactoryGirl.create(:security_group_amazon, :name => "sgn_1", :ext_management_system => ems,
                         :cloud_network => cloud_network1)
    end
    let(:floating_ip1) do
      FactoryGirl.create(:floating_ip_amazon, :cloud_network_only => true, :ems_id => ems.network_manager.id,
                         :cloud_network => cloud_network1)
    end

    let(:provreq_body) do
      {
        "template_fields" => {"guid" => template.guid},
        "requester"       => {
          "owner_first_name" => "John",
          "owner_last_name"  => "Doe",
          "owner_email"      => "user@example.com"
        }
      }
    end

    let(:expected_provreq_attributes) { %w(id options) }

    let(:expected_provreq_hash) do
      {
        "userid"         => api_config(:user),
        "requester_name" => api_config(:user_name),
        "approval_state" => "pending_approval",
        "type"           => "MiqProvisionRequest",
        "request_type"   => "template",
        "message"        => /Provisioning/i,
        "status"         => "Ok"
      }
    end

    it "supports manual placement" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      body = provreq_body.merge(
        "vm_fields" => {
          "vm_name"                     => "api_test_aws",
          "instance_type"               => flavor.id,
          "placement_auto"              => false,
          "placement_availability_zone" => az.id,
          "cloud_network"               => cloud_network1.id,
          "cloud_subnet"                => cloud_subnet1.id,
          "security_groups"             => security_group1.id,
          "floating_ip_address"         => floating_ip1.id
        }
      )

      run_post(provision_requests_url, body)

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_provreq_attributes)
      expect_results_to_match_hash("results", [expected_provreq_hash])

      expect(response_hash["results"].first).to include(
        "options" => include(
          "placement_auto"              => include(false),
          "placement_availability_zone" => include(az.id),
          "cloud_network"               => include(cloud_network1.id),
          "cloud_subnet"                => include(cloud_subnet1.id),
          "security_groups"             => include(security_group1.id),
          "floating_ip_address"         => include(floating_ip1.id)
        )
      )

      task_id = response_hash["results"].first["id"]
      expect(MiqProvisionRequest.exists?(task_id)).to be_truthy
    end

    it "does not process manual placement data if placement_auto is not set" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      body = provreq_body.merge(
        "vm_fields" => {
          "vm_name"                     => "api_test_aws",
          "instance_type"               => flavor.id,
          "placement_availability_zone" => az.id
        }
      )

      run_post(provision_requests_url, body)

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_provreq_attributes)
      expect_results_to_match_hash("results", [expected_provreq_hash])

      expect(response_hash["results"].first).to include(
        "options" => include(
          "placement_auto"              => include(true),
          "placement_availability_zone" => include(nil)
        )
      )

      task_id = response_hash["results"].first["id"]
      expect(MiqProvisionRequest.exists?(task_id)).to be_truthy
    end

    it "does not process manual placement data if placement_auto is set to true" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      body = provreq_body.merge(
        "vm_fields" => {
          "vm_name"                     => "api_test_aws",
          "instance_type"               => flavor.id,
          "placement_auto"              => true,
          "placement_availability_zone" => az.id
        }
      )

      run_post(provision_requests_url, body)

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_provreq_attributes)
      expect_results_to_match_hash("results", [expected_provreq_hash])

      expect(response_hash["results"].first).to include(
        "options" => include(
          "placement_auto"              => include(true),
          "placement_availability_zone" => include(nil)
        )
      )

      task_id = response_hash["results"].first["id"]
      expect(MiqProvisionRequest.exists?(task_id)).to be_truthy
    end
  end

  context "Provision requests approval" do
    let(:user)          { FactoryGirl.create(:user) }
    let(:template)      { FactoryGirl.create(:template_amazon) }
    let(:provreqbody)   { {:requester => user, :source_type => 'VmOrTemplate', :source_id => template.id} }
    let(:provreq1)      { FactoryGirl.create(:miq_provision_request, provreqbody) }
    let(:provreq2)      { FactoryGirl.create(:miq_provision_request, provreqbody) }
    let(:provreq1_url)  { provision_requests_url(provreq1.id) }
    let(:provreq2_url)  { provision_requests_url(provreq2.id) }
    let(:provreqs_list) { [provreq1_url, provreq2_url] }

    it "supports approving a request" do
      api_basic_authorize collection_action_identifier(:provision_requests, :approve)

      run_post(provreq1_url, gen_request(:approve))

      expected_msg = "Provision request #{provreq1.id} approved"
      expect_single_action_result(:success => true, :message => expected_msg, :href => :provreq1_url)
    end

    it "supports denying a request" do
      api_basic_authorize collection_action_identifier(:provision_requests, :approve)

      run_post(provreq2_url, gen_request(:deny))

      expected_msg = "Provision request #{provreq2.id} denied"
      expect_single_action_result(:success => true, :message => expected_msg, :href => :provreq2_url)
    end

    it "supports approving multiple requests" do
      api_basic_authorize collection_action_identifier(:provision_requests, :approve)

      run_post(provision_requests_url, gen_request(:approve, [{"href" => provreq1_url}, {"href" => provreq2_url}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :provreqs_list)
      expect_result_resources_to_match_key_data(
        "results",
        "message",
        [/Provision request #{provreq1.id} approved/i, /Provision request #{provreq2.id} approved/i]
      )
    end

    it "supports denying multiple requests" do
      api_basic_authorize collection_action_identifier(:provision_requests, :approve)

      run_post(provision_requests_url, gen_request(:deny, [{"href" => provreq1_url}, {"href" => provreq2_url}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :provreqs_list)
      expect_result_resources_to_match_key_data(
        "results",
        "message",
        [/Provision request #{provreq1.id} denied/i, /Provision request #{provreq2.id} denied/i]
      )
    end
  end
end

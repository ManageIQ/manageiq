#
# Rest API Request Tests - Provision Requests specs
#
# - Create single provision request    /api/provision_requests    normal POST
# - Create single provision request    /api/provision_requests    action "create"
# - Create multiple provision requests /api/provision_requests    action "create"
#
describe "Provision Requests API" do
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

      expect(response).to have_http_status(:forbidden)
    end

    it "supports single request with normal post" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      dialog  # Create the Provisioning dialog
      run_post(provision_requests_url, single_provision_request)

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)
      expect_results_to_match_hash("results", [expected_hash])

      task_id = response.parsed_body["results"].first["id"]
      expect(MiqProvisionRequest.exists?(task_id)).to be_truthy
    end

    it "supports single request with create action" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      dialog  # Create the Provisioning dialog
      run_post(provision_requests_url, gen_request(:create, single_provision_request))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)
      expect_results_to_match_hash("results", [expected_hash])

      task_id = response.parsed_body["results"].first["id"]
      expect(MiqProvisionRequest.exists?(task_id)).to be_truthy
    end

    it "supports multiple requests" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      dialog  # Create the Provisioning dialog
      run_post(provision_requests_url, gen_request(:create, [single_provision_request, single_provision_request]))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)
      expect_results_to_match_hash("results", [expected_hash, expected_hash])

      task_id1, task_id2 = response.parsed_body["results"].collect { |r| r["id"] }
      expect(MiqProvisionRequest.exists?(task_id1)).to be_truthy
      expect(MiqProvisionRequest.exists?(task_id2)).to be_truthy
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
      expect_single_action_result(:success => true, :message => expected_msg, :href => provreq1_url)
    end

    it "supports denying a request" do
      api_basic_authorize collection_action_identifier(:provision_requests, :approve)

      run_post(provreq2_url, gen_request(:deny))

      expected_msg = "Provision request #{provreq2.id} denied"
      expect_single_action_result(:success => true, :message => expected_msg, :href => provreq2_url)
    end

    it "supports approving multiple requests" do
      api_basic_authorize collection_action_identifier(:provision_requests, :approve)

      run_post(provision_requests_url, gen_request(:approve, [{"href" => provreq1_url}, {"href" => provreq2_url}]))

      expected = {
        "results" => a_collection_containing_exactly(
          {
            "message" => a_string_matching(/Provision request #{provreq1.id} approved/i),
            "success" => true,
            "href"    => a_string_matching(provreq1_url)
          },
          {
            "message" => a_string_matching(/Provision request #{provreq2.id} approved/i),
            "success" => true,
            "href"    => a_string_matching(provreq2_url)
          }
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "supports denying multiple requests" do
      api_basic_authorize collection_action_identifier(:provision_requests, :approve)

      run_post(provision_requests_url, gen_request(:deny, [{"href" => provreq1_url}, {"href" => provreq2_url}]))

      expected = {
        "results" => a_collection_containing_exactly(
          {
            "message" => a_string_matching(/Provision request #{provreq1.id} denied/i),
            "success" => true,
            "href"    => a_string_matching(provreq1_url)
          },
          {
            "message" => a_string_matching(/Provision request #{provreq2.id} denied/i),
            "success" => true,
            "href"    => a_string_matching(provreq2_url)
          }
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end
end

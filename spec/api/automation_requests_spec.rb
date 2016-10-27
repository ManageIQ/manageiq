#
# Rest API Request Tests - Automation Requests specs
#
# - Create single automation request    /api/automation_requests    normal POST
# - Create single automation request    /api/automation_requests    action "create"
# - Create multiple automation requests /api/automation_requests    action "create"
#
# - Approve single automation request      /api/automation_requests/:id    action "approve"
# - Approve multiple automation requests   /api/automation_requests        action "approve"
# - Deny single automation request         /api/automation_requests/:id    action "deny"
# - Deny multiple automation requests      /api/automation_requests        action "deny"
#
describe "Automation Requests API" do
  describe "Automation Requests" do
    let(:approver) { FactoryGirl.create(:user_miq_request_approver) }
    let(:single_automation_request) do
      {
        "uri_parts"  => {"
          namespace" => "System", "class" => "Request", "instance" => "InspectME", "message" => "create"
         },
        "parameters" => {"var1" => "xyzzy", "var2" => 1024, "var3" => true},
        "requester"  => {"user_name" => approver.userid, "auto_approve" => true}
      }
    end
    let(:expected_hash) do
      {"approval_state" => "approved", "type" => "AutomationRequest", "request_type" => "automation", "status" => "Ok"}
    end

    it "supports single request with normal post" do
      api_basic_authorize

      run_post(automation_requests_url, single_automation_request)

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", %w(id approval_state type request_type status options))
      expect_results_to_match_hash("results", [expected_hash])

      task_id = response.parsed_body["results"].first["id"]
      expect(AutomationRequest.exists?(task_id)).to be_truthy
    end

    it "supports single request with create action" do
      api_basic_authorize

      run_post(automation_requests_url, gen_request(:create, single_automation_request))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", %w(id approval_state type request_type status options))
      expect_results_to_match_hash("results", [expected_hash])

      task_id = response.parsed_body["results"].first["id"]
      expect(AutomationRequest.exists?(task_id)).to be_truthy
    end

    it "supports multiple requests" do
      api_basic_authorize

      run_post(automation_requests_url, gen_request(:create, [single_automation_request, single_automation_request]))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", %w(id approval_state type request_type status options))
      expect_results_to_match_hash("results", [expected_hash, expected_hash])

      task_id1, task_id2 = response.parsed_body["results"].collect { |r| r["id"] }
      expect(AutomationRequest.exists?(task_id1)).to be_truthy
      expect(AutomationRequest.exists?(task_id2)).to be_truthy
    end
  end

  context "Automation requests approval" do
    let(:template)      { FactoryGirl.create(:template_amazon) }
    let(:request_body)  { {:requester => @user, :source_type => 'VmOrTemplate', :source_id => template.id} }
    let(:request1)      { FactoryGirl.create(:automation_request, request_body) }
    let(:request1_url)  { automation_requests_url(request1.id) }
    let(:request2)      { FactoryGirl.create(:automation_request, request_body) }
    let(:request2_url)  { automation_requests_url(request2.id) }

    it "supports approving a request" do
      api_basic_authorize collection_action_identifier(:automation_requests, :approve)

      run_post(request1_url, gen_request(:approve, :reason => "approve reason"))

      expected_msg = "Automation request #{request1.id} approved"
      expect_single_action_result(:success => true, :message => expected_msg, :href => request1_url)
    end

    it "supports denying a request" do
      api_basic_authorize collection_action_identifier(:automation_requests, :deny)

      run_post(request2_url, gen_request(:deny, :reason => "deny reason"))

      expected_msg = "Automation request #{request2.id} denied"
      expect_single_action_result(:success => true, :message => expected_msg, :href => request2_url)
    end

    it "supports approving multiple requests" do
      api_basic_authorize collection_action_identifier(:automation_requests, :approve)

      run_post(automation_requests_url, gen_request(:approve, [{"href" => request1_url, "reason" => "approve reason"},
                                                               {"href" => request2_url, "reason" => "approve reason"}]))

      expected = {
        "results" => a_collection_containing_exactly(
          {
            "message" => a_string_matching(/Automation request #{request1.id} approved/i),
            "success" => true,
            "href"    => a_string_matching(request1_url)
          },
          {
            "message" => a_string_matching(/Automation request #{request2.id} approved/i),
            "success" => true,
            "href"    => a_string_matching(request2_url)
          }
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "supports denying multiple requests" do
      api_basic_authorize collection_action_identifier(:automation_requests, :deny)

      run_post(automation_requests_url, gen_request(:deny, [{"href" => request1_url, "reason" => "deny reason"},
                                                            {"href" => request2_url, "reason" => "deny reason"}]))

      expected = {
        "results" => a_collection_containing_exactly(
          {
            "message" => a_string_matching(/Automation request #{request1.id} denied/i,),
            "success" => true,
            "href"    => a_string_matching(request1_url)
          },
          {
            "message" => a_string_matching(/Automation request #{request2.id} denied/i),
            "success" => true,
            "href"    => a_string_matching(request2_url)
          }
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end
end

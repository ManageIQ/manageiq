#
# Rest API Request Tests - Automation Requests specs
#
# - Create single automation request    /api/automation_requests    normal POST
# - Create single automation request    /api/automation_requests    action "create"
# - Create multiple automation requests /api/automation_requests    action "create"
#
describe ApiController do
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

      expect_request_success
      expect_result_resources_to_include_keys("results", %w(id approval_state type request_type status options))
      expect_results_to_match_hash("results", [expected_hash])

      task_id = @result["results"].first["id"]
      expect(AutomationRequest.exists?(task_id)).to be_truthy
    end

    it "supports single request with create action" do
      api_basic_authorize

      run_post(automation_requests_url, gen_request(:create, single_automation_request))

      expect_request_success
      expect_result_resources_to_include_keys("results", %w(id approval_state type request_type status options))
      expect_results_to_match_hash("results", [expected_hash])

      task_id = @result["results"].first["id"]
      expect(AutomationRequest.exists?(task_id)).to be_truthy
    end

    it "supports multiple requests" do
      api_basic_authorize

      run_post(automation_requests_url, gen_request(:create, [single_automation_request, single_automation_request]))

      expect_request_success
      expect_result_resources_to_include_keys("results", %w(id approval_state type request_type status options))
      expect_results_to_match_hash("results", [expected_hash, expected_hash])

      task_id1, task_id2 = @result["results"].collect { |r| r["id"] }
      expect(AutomationRequest.exists?(task_id1)).to be_truthy
      expect(AutomationRequest.exists?(task_id2)).to be_truthy
    end
  end
end

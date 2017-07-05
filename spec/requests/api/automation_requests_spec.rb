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

    it "filters the list of automation requests by requester" do
      other_user = FactoryGirl.create(:user)
      _automation_request1 = FactoryGirl.create(:automation_request, :requester => other_user)
      automation_request2 = FactoryGirl.create(:automation_request, :requester => @user)
      api_basic_authorize collection_action_identifier(:automation_requests, :read, :get)

      run_get automation_requests_url

      expected = {
        "count"     => 2,
        "subcount"  => 1,
        "resources" => a_collection_containing_exactly(
          "href" => a_string_matching(automation_requests_url(automation_request2.id)),
        )
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it "lists all the automation requests if you are admin" do
      @group.miq_user_role = @role = FactoryGirl.create(:miq_user_role, :role => "administrator")
      other_user = FactoryGirl.create(:user)
      automation_request1 = FactoryGirl.create(:automation_request, :requester => other_user)
      automation_request2 = FactoryGirl.create(:automation_request, :requester => @user)
      api_basic_authorize collection_action_identifier(:automation_requests, :read, :get)

      run_get automation_requests_url

      expected = {
        "count"     => 2,
        "subcount"  => 2,
        "resources" => a_collection_containing_exactly(
          {"href" => a_string_matching(automation_requests_url(automation_request1.id))},
          {"href" => a_string_matching(automation_requests_url(automation_request2.id))},
        )
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it "restricts access to automation requests to requester" do
      other_user = FactoryGirl.create(:user)
      automation_request = FactoryGirl.create(:automation_request, :requester => other_user)
      api_basic_authorize action_identifier(:automation_requests, :read, :resource_actions, :get)

      run_get automation_requests_url(automation_request.id)

      expect(response).to have_http_status(:not_found)
    end

    it "an admin can see another user's request" do
      @group.miq_user_role = @role = FactoryGirl.create(:miq_user_role, :role => "administrator")
      other_user = FactoryGirl.create(:user)
      automation_request = FactoryGirl.create(:automation_request, :requester => other_user)
      api_basic_authorize action_identifier(:automation_requests, :read, :resource_actions, :get)

      run_get automation_requests_url(automation_request.id)

      expected = {
        "id"   => automation_request.id,
        "href" => a_string_matching(automation_requests_url(automation_request.id))
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it "supports single request with normal post" do
      api_basic_authorize

      run_post(automation_requests_url, single_automation_request)

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", %w(id approval_state type request_type status options))
      expect_results_to_match_hash("results", [expected_hash])

      task_id = ApplicationRecord.uncompress_id(response.parsed_body["results"].first["id"])
      expect(AutomationRequest.exists?(task_id)).to be_truthy
    end

    it "supports single request with create action" do
      api_basic_authorize

      run_post(automation_requests_url, gen_request(:create, single_automation_request))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", %w(id approval_state type request_type status options))
      expect_results_to_match_hash("results", [expected_hash])

      task_id = ApplicationRecord.uncompress_id(response.parsed_body["results"].first["id"])
      expect(AutomationRequest.exists?(task_id)).to be_truthy
    end

    it "supports multiple requests" do
      api_basic_authorize

      run_post(automation_requests_url, gen_request(:create, [single_automation_request, single_automation_request]))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", %w(id approval_state type request_type status options))
      expect_results_to_match_hash("results", [expected_hash, expected_hash])

      task_id1, task_id2 = response.parsed_body["results"].collect { |r| ApplicationRecord.uncompress_id(r["id"]) }
      expect(AutomationRequest.exists?(task_id1)).to be_truthy
      expect(AutomationRequest.exists?(task_id2)).to be_truthy
    end
  end

  describe "automation request update" do
    it 'forbids provision request update without an appropriate role' do
      automation_request = FactoryGirl.create(:automation_request, :requester => @user, :options => {:foo => "bar"})
      api_basic_authorize

      run_post(automation_requests_url(automation_request.id), :action => "edit", :options => {:baz => "qux"})

      expect(response).to have_http_status(:forbidden)
    end

    it 'updates a single provision request' do
      automation_request = FactoryGirl.create(:automation_request, :requester => @user, :options => {:foo => "bar"})
      api_basic_authorize(action_identifier(:automation_requests, :edit))

      run_post(automation_requests_url(automation_request.id), :action => "edit", :options => {:baz => "qux"})

      expected = {
        "id"      => automation_request.compressed_id,
        "options" => a_hash_including("foo" => "bar", "baz" => "qux")
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'updates multiple provision requests' do
      automation_request, automation_request2 = FactoryGirl.create_list(:automation_request,
                                                                        2,
                                                                        :requester => @user,
                                                                        :options   => {:foo => "bar"})
      api_basic_authorize collection_action_identifier(:service_requests, :edit)

      run_post(
        automation_requests_url,
        :action    => "edit",
        :resources => [
          {:id => automation_request.id, :options => {:baz => "qux"}},
          {:id => automation_request2.id, :options => {:quux => "quuz"}}
        ]
      )

      expected = {
        'results' => a_collection_containing_exactly(
          a_hash_including("options" => a_hash_including("foo" => "bar", "baz" => "qux")),
          a_hash_including("options" => a_hash_including("foo" => "bar", "quux" => "quuz"))
        )
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
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

  context 'Tasks subcollection' do
    let(:automation_request) { FactoryGirl.create(:automation_request) }

    it 'redirects to request_tasks subcollection' do
      FactoryGirl.create(:miq_request_task, :miq_request_id => automation_request.id)
      api_basic_authorize

      run_get("#{automation_requests_url(automation_request.id)}/tasks")

      expect(response).to have_http_status(:moved_permanently)
      expect(response.redirect_url).to include("#{automation_requests_url(automation_request.id)}/request_tasks")
    end

    it 'redirects to request_tasks subresources' do
      task = FactoryGirl.create(:miq_request_task, :miq_request_id => automation_request.id)
      api_basic_authorize

      run_get("#{automation_requests_url(automation_request.id)}/tasks/#{task.id}")

      expect(response).to have_http_status(:moved_permanently)
      expect(response.redirect_url).to include("#{automation_requests_url(automation_request.id)}/request_tasks/#{task.id}")
    end
  end
end

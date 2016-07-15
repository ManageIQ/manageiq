RSpec.describe "Requests API" do
  let(:template) { FactoryGirl.create(:service_template, :name => "ServiceTemplate") }

  context "authorization" do
    it "is forbidden for a user without appropriate role" do
      api_basic_authorize

      run_get requests_url

      expect(response).to have_http_status(:forbidden)
    end

    it "does not list another user's requests" do
      other_user = FactoryGirl.create(:user)
      FactoryGirl.create(:service_template_provision_request,
                         :requester   => other_user,
                         :source_id   => template.id,
                         :source_type => template.class.name)
      api_basic_authorize collection_action_identifier(:requests, :read, :get)

      run_get requests_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("name" => "requests", "count" => 1, "subcount" => 0)
    end

    it "does not show another user's request" do
      other_user = FactoryGirl.create(:user)
      service_request = FactoryGirl.create(:service_template_provision_request,
                                           :requester   => other_user,
                                           :source_id   => template.id,
                                           :source_type => template.class.name)
      api_basic_authorize action_identifier(:requests, :read, :resource_actions, :get)

      run_get requests_url(service_request.id)

      expected = {
        "error" => a_hash_including(
          "message" => /Couldn't find MiqRequest/
        )
      }
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to include(expected)
    end

    it "a user can list their own requests" do
      _service_request = FactoryGirl.create(:service_template_provision_request,
                                            :requester   => @user,
                                            :source_id   => template.id,
                                            :source_type => template.class.name)
      api_basic_authorize collection_action_identifier(:requests, :read, :get)

      run_get requests_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("name" => "requests", "count" => 1, "subcount" => 1)
    end

    it "a user can show their own request" do
      service_request = FactoryGirl.create(:service_template_provision_request,
                                           :requester   => @user,
                                           :source_id   => template.id,
                                           :source_type => template.class.name)
      api_basic_authorize action_identifier(:requests, :read, :resource_actions, :get)

      run_get requests_url(service_request.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id"   => service_request.id,
                                       "href" => a_string_matching(service_requests_url(service_request.id)))
    end

    it "lists all the service requests if you are admin" do
      allow_any_instance_of(User).to receive(:admin?).and_return(true)
      other_user = FactoryGirl.create(:user)
      service_request_1 = FactoryGirl.create(:service_template_provision_request,
                                             :requester   => other_user,
                                             :source_id   => template.id,
                                             :source_type => template.class.name)
      service_request_2 = FactoryGirl.create(:service_template_provision_request,
                                             :requester   => @user,
                                             :source_id   => template.id,
                                             :source_type => template.class.name)
      api_basic_authorize collection_action_identifier(:requests, :read, :get)

      run_get requests_url

      expected = {
        "count"     => 2,
        "subcount"  => 2,
        "resources" => a_collection_containing_exactly(
          {"href" => a_string_matching(requests_url(service_request_1.id))},
          {"href" => a_string_matching(requests_url(service_request_2.id))},
        )
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it "an admin can see another user's request" do
      allow_any_instance_of(User).to receive(:admin?).and_return(true)
      other_user = FactoryGirl.create(:user)
      service_request = FactoryGirl.create(:service_template_provision_request,
                                           :requester   => other_user,
                                           :source_id   => template.id,
                                           :source_type => template.class.name)
      api_basic_authorize action_identifier(:requests, :read, :resource_actions, :get)

      run_get requests_url(service_request.id)

      expected = {
        "id"   => service_request.id,
        "href" => a_string_matching(service_requests_url(service_request.id))
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end
  end
end

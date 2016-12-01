describe "Alert Status API" do
  let(:alert_status) { FactoryGirl.create(:miq_alert_status) }
  let(:alert_status_url) { alert_statuses_url(alert_status.id) }
  let(:container_provider) { FactoryGirl.create(:ems_container) }
  let(:infra_provider) { FactoryGirl.create(:ems_infra) }
  let(:vm) { FactoryGirl.create(:vm) }
  let(:miq_alert_status_state) do
    FactoryGirl.create(:miq_alert_status_state,
                       :miq_alert_status => alert_status,
                       :comment          => "Big problem",
                       :user             => user,
                       :assignee         => user)
  end
  let(:container_node) { FactoryGirl.create(:kubernetes_node, :name => "example.com") }
  let(:miq_alert) { FactoryGirl.create(:miq_alert, :severity => "info") }
  let(:user) { FactoryGirl.create(:user_with_group) }

  it "forbids access to actions without an appropriate role" do
    api_basic_authorize

    run_get(alert_statuses_url)

    expect(response).to have_http_status(:forbidden)
  end

  it "reads all alerts statuses" do
    api_basic_authorize collection_action_identifier(:alert_statuses, :read, :get)
    alert_status
    run_get(alert_statuses_url)
    expect(response).to have_http_status(:ok)

    expect(response.parsed_body["count"]).to eq(1)
  end

  context "alerts status subcollection" do
    before do
      alert_status.miq_alert = miq_alert
      miq_alert_status_state
      alert_status.save!
      api_basic_authorize collection_action_identifier(:providers, :read, :get)
    end

    it "get all alerts statuses by container provider" do
      expected_result_container = {"environment" => "production",
                                   "alerts"      =>
                                                    [{"id"            => alert_status.id,
                                                      "node_hostname" => container_node.name,
                                                      "severity"      => miq_alert.severity,
                                                      "description"   => miq_alert.description,
                                                      "states"        => [
                                                        {
                                                          "id"                => miq_alert_status_state.id,
                                                          "created_at"        => miq_alert_status_state.created_at.utc.iso8601,
                                                          "updated_at"        => miq_alert_status_state.updated_at.utc.iso8601,
                                                          "user_id"           => user.id,
                                                          "assignee_id"       => user.id,
                                                          "action"            => "comment",
                                                          "comment"           => miq_alert_status_state.comment,
                                                          "username"          => miq_alert_status_state.user.name,
                                                          "assignee_username" => miq_alert_status_state.assignee.name
                                                        }
                                                      ]}]}
      container_provider.container_nodes << container_node
      container_node.miq_alert_statuses << alert_status
      run_get("#{providers_url}?expand=resources,alert_statuses")
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"].first["alert_statuses"]).to include(expected_result_container)
    end

    it "get all alerts statuses by infra provider" do
      expected_result_infra = {"environment" => "production",
                               "alerts"      =>
                                                [{"id"            => alert_status.id,
                                                  "node_hostname" => vm.name,
                                                  "severity"      => miq_alert.severity,
                                                  "description"   => miq_alert.description,
                                                  "states"        => [
                                                    {
                                                      "id"                => miq_alert_status_state.id,
                                                      "created_at"        => miq_alert_status_state.created_at.utc.iso8601,
                                                      "updated_at"        => miq_alert_status_state.updated_at.utc.iso8601,
                                                      "user_id"           => user.id,
                                                      "assignee_id"       => user.id,
                                                      "action"            => "comment",
                                                      "comment"           => miq_alert_status_state.comment,
                                                      "username"          => miq_alert_status_state.user.name,
                                                      "assignee_username" => miq_alert_status_state.assignee.name
                                                    }
                                                  ]}]}
      infra_provider.vms << vm
      vm.miq_alert_statuses << alert_status
      run_get("#{providers_url}?expand=resources,alert_statuses")
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"].first["alert_statuses"]).to include(expected_result_infra)
    end
  end
end

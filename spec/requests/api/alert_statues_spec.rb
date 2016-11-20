describe "Alert Status API" do
  let(:alert_status) { FactoryGirl.create(:miq_alert_status) }
  let(:alert_status_url) { alert_statuses_url(alert_status.id) }
  let(:container_provider) { FactoryGirl.create(:ems_container) }
  let(:infra_provider) { FactoryGirl.create(:ems_infra) }
  let(:vm) { FactoryGirl.create(:vm) }
  let(:miq_alert_status_state) { FactoryGirl.create(:miq_alert_status_state, :miq_alert_status => alert_status, :comment => "Big problem", :user => user, :assignee => user) }

  let(:container_node) { FactoryGirl.create(:kubernetes_node) }
  let(:miq_alert) { FactoryGirl.create(:miq_alert, :severity => "info") }
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:expected_result_container) do
    {"providers" =>
                    [{"environment" => "production",
                      "name"        => container_provider.name,
                      "type"        => container_provider.type,
                      "id"          => container_provider.id,
                      "alerts"      =>
                                       [{"id"            => alert_status.id,
                                         "evaluated_on"  => nil,
                                         "link_text"     => nil,
                                         "node_hostname" => container_node.name,
                                         "severity"      => miq_alert.severity,
                                         "description"   => miq_alert.description,
                                         "states"        => [
                                           {
                                             "id"                => miq_alert_status_state.id,
                                             "created_at"        => miq_alert_status_state.created_at.to_time.to_i,
                                             "updated_at"        => miq_alert_status_state.updated_at.to_time.to_i,
                                             "user_id"           => user.id,
                                             "assignee_id"       => user.id,
                                             "action"            => "comment",
                                             "comment"           => miq_alert_status_state.comment,
                                             "username"          => miq_alert_status_state.user.name,
                                             "assignee_username" => miq_alert_status_state.assignee.name
                                           }
                                         ]}]}]}
  end
  let(:expected_result_infra) do
    {"providers" =>
                    [{"environment" => "production",
                      "name"        => infra_provider.name,
                      "type"        => infra_provider.type,
                      "id"          => infra_provider.id,
                      "alerts"      =>
                                       [{"id"            => alert_status.id,
                                         "evaluated_on"  => nil,
                                         "link_text"     => nil,
                                         "node_hostname" => vm.name,
                                         "severity"      => miq_alert.severity,
                                         "description"   => miq_alert.description,
                                         "states"        => [
                                           {
                                             "id"                => miq_alert_status_state.id,
                                             "created_at"        => miq_alert_status_state.created_at.to_time.to_i,
                                             "updated_at"        => miq_alert_status_state.updated_at.to_time.to_i,
                                             "user_id"           => user.id,
                                             "assignee_id"       => user.id,
                                             "action"            => "comment",
                                             "comment"           => miq_alert_status_state.comment,
                                             "username"          => miq_alert_status_state.user.name,
                                             "assignee_username" => miq_alert_status_state.assignee.name
                                           }
                                         ]}]}]}
  end

  before :each do
  end

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

    alert_statues_amount = response.parsed_body["count"]

    expect(alert_statues_amount).to eq(1)
  end

  it "deletes alert status" do
    api_basic_authorize action_identifier(:alert_statuses, :delete)
    run_post(alert_status_url, gen_request(:delete, "href" => alert_status_url))
    expect(response).to have_http_status(:ok)

    expect(MiqAlertStatus.exists?(alert_status.id)).to be_falsey
  end

  it "edits new alert status" do
    api_basic_authorize action_identifier(:alert_statuses, :edit)
    expect(alert_status.result).to be_falsey
    run_post(alert_status_url, gen_request(:edit, "result" => true))
    expect(response).to have_http_status(:ok)

    expect(alert_status.reload.result).to eq(true)
  end

  context "options" do
    before :each do
      alert_status.miq_alert = miq_alert
      miq_alert_status_state
      alert_status.save!
      api_basic_authorize
    end

    it "get all alerts statuses by container provider" do
      container_provider.container_nodes << container_node
      container_node.miq_alert_statuses << alert_status
      run_options(alert_statuses_url)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to include(expected_result_container)
    end

    it "get all alerts statuses by infra provider" do
      infra_provider.vms << vm
      vm.miq_alert_statuses << alert_status
      run_options(alert_statuses_url)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to include(expected_result_infra)
    end
  end
end

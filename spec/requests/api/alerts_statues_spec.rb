describe "Alert Status API" do
  let(:alert_status) { FactoryGirl.create(:miq_alert_status) }
  let(:alert_status_url) { alerts_statuses_url(alert_status.id) }
  let(:container_provider) { FactoryGirl.create(:ems_container) }
  let(:infra_provider) { FactoryGirl.create(:ems_infra) }
  let(:vm) { FactoryGirl.create(:vm) }
  let(:miq_alert_status_state) { FactoryGirl.create(:miq_alert_status_state, :miq_alert_status => alert_status, :comment => "Big problem", :user => user, :assignee => user) }

  let(:container_node) { FactoryGirl.create(:kubernetes_node) }
  let(:miq_alert) { FactoryGirl.create(:miq_alert, :severity => "info") }
  let(:user)  { FactoryGirl.create(:user_with_group) }

  it "forbids access to actions without an appropriate role" do
    alert_status
    api_basic_authorize

    run_get(alerts_statuses_url)

    expect(response).to have_http_status(:forbidden)
  end

  it "reads all alerts statuses" do
    api_basic_authorize collection_action_identifier(:alerts_statuses, :read, :get)
    alert_status
    run_get(alerts_statuses_url)
    expect(response).to have_http_status(:ok)

    alert_statues_amount = response.parsed_body["count"]

    expect(alert_statues_amount).to eq(1)
  end

  it "deletes alert status" do
    api_basic_authorize action_identifier(:alerts_statuses, :delete)
    run_post(alert_status_url, gen_request(:delete, "href" => alert_status_url))
    expect(response).to have_http_status(:ok)

    expect(MiqAlertStatus.exists?(alert_status.id)).to be_falsey
  end

  it "edits new alert status" do
    api_basic_authorize action_identifier(:alerts_statuses, :edit)
    expect(alert_status.result).to be_falsey
    run_post(alert_status_url, gen_request(:edit, "result" => true))
    expect(response).to have_http_status(:ok)

    expect(alert_status.reload.result).to eq(true)
  end

  it "get all alerts statuses by container provider" do
    api_basic_authorize collection_action_identifier(:alerts_statuses, :providers_alerts)
    container_provider.container_nodes << container_node
    container_node.miq_alert_statuses << alert_status
    alert_status.miq_alert = miq_alert
    alert_status.save!
    run_post(alerts_statuses_url, gen_request(:providers_alerts))
    expect(response).to have_http_status(:ok)
    first_provider = response.parsed_body["providers"].first
    expect(response.parsed_body["providers"].count).to eq(1)
    expect(first_provider["name"]).to eq(container_provider.name)
    expect(first_provider["type"]).to eq(container_provider.class.to_s)
    expect(first_provider["id"]).to eq(container_provider.id)
    expect(first_provider["alerts"].count).to eq(1)
    expect(first_provider["alerts"].first["description"]).to eq(miq_alert.description)
  end

  it "returns alert status state" do
    api_basic_authorize collection_action_identifier(:alerts_statuses, :providers_alerts)
    container_provider.container_nodes << container_node
    container_node.miq_alert_statuses << alert_status
    alert_status.miq_alert = miq_alert
    alert_status.save!
    miq_alert_status_state

    run_post(alerts_statuses_url, gen_request(:providers_alerts))
    first_provider = response.parsed_body["providers"].first

    expect(response).to have_http_status(:ok)
    expect(first_provider["alerts"].first["states"].first["comment"]).to eq(miq_alert_status_state.comment)
    expect(first_provider["alerts"].first["states"].first["username"]).to eq(miq_alert_status_state.user.name)
    expect(first_provider["alerts"].first["states"].first["assignee_username"]).to eq(miq_alert_status_state.assignee.name)
  end

  it "get all alerts statuses by infra provider" do
    api_basic_authorize collection_action_identifier(:alerts_statuses, :providers_alerts)
    infra_provider.vms << vm
    vm.miq_alert_statuses << alert_status
    alert_status.miq_alert = miq_alert
    alert_status.save!
    run_post(alerts_statuses_url, gen_request(:providers_alerts))
    expect(response).to have_http_status(:ok)
    first_provider = response.parsed_body["providers"].first
    expect(response.parsed_body["providers"].count).to eq(1)
    expect(first_provider["name"]).to eq(infra_provider.name)
    expect(first_provider["type"]).to eq(infra_provider.class.to_s)
    expect(first_provider["id"]).to eq(infra_provider.id)
    expect(first_provider["alerts"].count).to eq(1)
    expect(first_provider["alerts"].first["description"]).to eq(miq_alert.description)
  end
end

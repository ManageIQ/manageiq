describe "Alerts API" do
  let(:alert_definition) { FactoryGirl.create(:miq_alert, :severity => "info") }

  it "forbids access to alerts list without an appropriate role" do
    api_basic_authorize
    run_get(alerts_url)
    expect(response).to have_http_status(:forbidden)
  end

  it "reads 2 alerts as a collection" do
    api_basic_authorize collection_action_identifier(:alerts, :read, :get)
    alert_statuses = FactoryGirl.create_list(:miq_alert_status, 2)
    run_get(alerts_url)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "name"      => "alerts",
      "count"     => 2,
      "subcount"  => 2,
      "resources" => [
        {
          "href" => a_string_matching(alerts_url(alert_statuses[0].id))
        },
        {
          "href" => a_string_matching(alerts_url(alert_statuses[1].id))
        }
      ]
    )
  end

  it "forbids access to an alert resource without an appropriate role" do
    api_basic_authorize
    alert_status = FactoryGirl.create(:miq_alert_status)
    run_get(alerts_url(alert_status.id))
    expect(response).to have_http_status(:forbidden)
  end

  it "reads an alert as a resource" do
    api_basic_authorize action_identifier(:alerts, :read, :resource_actions, :get)
    alert_status = FactoryGirl.create(:miq_alert_status)
    run_get(alerts_url(alert_status.id))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "href" => a_string_matching(alerts_url(alert_status.id)),
      "id"   => alert_status.id
    )
  end
end

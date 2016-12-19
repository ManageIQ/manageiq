describe "Alerts API" do
  let(:alert_definition) { FactoryGirl.create(:miq_alert, :severity => "info") }

  it "forbids access to actions without an appropriate role" do
    api_basic_authorize
    run_get(alerts_url)
    expect(response).to have_http_status(:forbidden)
  end

  it "reads all alerts statuses" do
    api_basic_authorize collection_action_identifier(:alerts, :read, :get)
    alert_status_1, alert_status_2 = FactoryGirl.create_list(:miq_alert_status, 2)
    run_get(alerts_url)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["count"]).to eq(2)
  end
end

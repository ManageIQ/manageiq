RSpec.describe "Alert Status States API" do
  let(:miq_alert_status) { FactoryGirl.create(:miq_alert_status) }
  let(:miq_alert_status_state) { FactoryGirl.create(:miq_alert_status_state, :miq_alert_status => miq_alert_status, :comment => "Big problem") }

  it "can delete a alert status state through its nested URI" do
    miq_alert_status
    miq_alert_status_state

    api_basic_authorize subcollection_action_identifier(:alert_statuses, :alert_status_states, :delete, :post)
    expect do
      run_post("#{alert_statuses_url(miq_alert_status.id)}/alert_status_states/#{miq_alert_status_state.id}", gen_request(:delete))
    end.to change(MiqAlertStatusState, :count).by(-1)
    expect(response.parsed_body).to include("id" => miq_alert_status_state.id)
  end

  it "can add a alert status state through its nested URI" do
    api_basic_authorize subcollection_action_identifier(:alert_statuses, :alert_status_states, :edit, :post)
    run_post("#{alert_statuses_url(miq_alert_status.id)}/alert_status_states/#{miq_alert_status_state.id}",
             gen_request(:edit, 'comment' => "I was worng"))
    expect(response.parsed_body).to include("miq_alert_status_id" => miq_alert_status.id, "comment" => "I was worng", "action" => "comment")
  end

  it "can add a alert status state through its nested URI" do
    api_basic_authorize subcollection_action_identifier(:alert_statuses, :alert_status_states, :add, :post)
    run_post("#{alert_statuses_url(miq_alert_status.id)}/alert_status_states",
             gen_request(:add, 'comment' => "I was worng", :action => "comment"))
    expect(response.parsed_body["results"].first).to include("miq_alert_status_id" => miq_alert_status.id, "comment" => "I was worng", "action" => "comment")
  end

  it "can read all alert status state through its nested URI" do
    miq_alert_status_state
    api_basic_authorize
    run_get("#{alert_statuses_url(miq_alert_status.id)}/alert_status_states")
    expect(response.parsed_body["count"]).to eq(1)
  end
end

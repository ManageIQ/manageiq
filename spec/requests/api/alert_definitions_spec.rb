#
# REST API Request Tests - Alert Definitions
#
# Alert Definitions primary collections:
#   /api/alert_definitions
#

describe "Alerts Definitions API" do
  it "forbids access to alert definitions list without an appropriate role" do
    api_basic_authorize
    run_get(alert_definitions_url)
    expect(response).to have_http_status(:forbidden)
  end

  it "reads 2 alert definitions as a collection" do
    api_basic_authorize collection_action_identifier(:alert_definitions, :read, :get)
    alert_definitions = FactoryGirl.create_list(:miq_alert, 2)
    run_get(alert_definitions_url)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "name"      => "alert_definitions",
      "count"     => 2,
      "subcount"  => 2,
      "resources" => [
        {
          "href" => a_string_matching(alert_definitions_url(alert_definitions[0].id))
        },
        {
          "href" => a_string_matching(alert_definitions_url(alert_definitions[1].id))
        }
      ]
    )
  end

  it "forbids access to an alert definition resource without an appropriate role" do
    api_basic_authorize
    alert_definition = FactoryGirl.create(:miq_alert)
    run_get(alert_definitions_url(alert_definition.id))
    expect(response).to have_http_status(:forbidden)
  end

  it "reads an alert as a resource" do
    api_basic_authorize action_identifier(:alert_definitions, :read, :resource_actions, :get)
    alert_definition = FactoryGirl.create(:miq_alert)
    run_get(alert_definitions_url(alert_definition.id))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "href"        => a_string_matching(alert_definitions_url(alert_definition.id)),
      "id"          => alert_definition.id,
      "description" => alert_definition.description,
      "guid"        => alert_definition.guid
    )
  end

  it "forbids creation of an alert definition without an appropriate role" do
    api_basic_authorize
    alert_definition = {
      "description" => "Test Alert Definition",
      "db"          => "ContainerNode"
    }
    run_post(alert_definitions_url, alert_definition)
    expect(response).to have_http_status(:forbidden)
  end

  it "creates an alert definition" do
    sample_alert_definition = {
      "description" => "Test Alert Definition",
      "db"          => "ContainerNode",
      "expression"  => { "eval_method" => "dwh_generic", "mode" => "internal", "options" => {} },
      "options"     => { "notifications" => {"delay_next_evaluation" => 600, "evm_event" => {} } },
      "enabled"     => true
    }
    api_basic_authorize collection_action_identifier(:alert_definitions, :create)
    run_post(alert_definitions_url, sample_alert_definition)
    expect(response).to have_http_status(:ok)
    alert_definition = MiqAlert.find(response.parsed_body["results"].first["id"])
    expect(alert_definition).to be_truthy
    expect(alert_definition.expression.class).to eq(MiqExpression)
    expect(alert_definition.expression.exp).to eq(sample_alert_definition["expression"])
    expect(response.parsed_body["results"].first).to include(
      "description" => sample_alert_definition["description"],
      "db"          => sample_alert_definition["db"],
      "expression"  => a_hash_including(
        "exp" => sample_alert_definition["expression"]
      )
    )
  end

  it "deletes an alert definition via POST" do
    api_basic_authorize action_identifier(:alert_definitions, :delete, :resource_actions, :post)
    alert_definition = FactoryGirl.create(:miq_alert)
    run_post(alert_definitions_url(alert_definition.id), gen_request(:delete))
    expect(response).to have_http_status(:ok)
    expect_single_action_result(:success => true,
                                :message => "alert_definitions id: #{alert_definition.id} deleting",
                                :href    => alert_definitions_url(alert_definition.id))
  end

  it "deletes an alert definition via DELETE" do
    api_basic_authorize action_identifier(:alert_definitions, :delete, :resource_actions, :delete)
    alert_definition = FactoryGirl.create(:miq_alert)
    run_delete(alert_definitions_url(alert_definition.id))
    expect(response).to have_http_status(:no_content)
    expect(MiqAlert.exists?(alert_definition.id)).to be_falsey
  end

  it "deletes alert definitions" do
    api_basic_authorize collection_action_identifier(:alert_definitions, :delete)
    alert_definitions = FactoryGirl.create_list(:miq_alert, 2)
    run_post(alert_definitions_url, gen_request(:delete, [{"id" => alert_definitions.first.id},
                                                          {"id" => alert_definitions.second.id}]))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["results"].count).to eq(2)
  end

  it "edits an alert definition" do
    sample_alert_definition = {
      :description => "Test Alert Definition",
      :db          => "ContainerNode",
      :expression  => { :eval_method => "dwh_generic", :mode => "internal", :options => {} },
      :options     => { :notifications => {:delay_next_evaluation => 600, :evm_event => {} } },
      :enabled     => true
    }
    updated_options = { :notifications => {:delay_next_evaluation => 60, :evm_event => {} } }
    api_basic_authorize action_identifier(:alert_definitions, :edit, :resource_actions, :post)
    alert_definition = FactoryGirl.create(:miq_alert, sample_alert_definition)
    run_post(alert_definitions_url(alert_definition.id), gen_request(:edit, :options => updated_options))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["options"]).to eq(updated_options.deep_stringify_keys)
  end
end

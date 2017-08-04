#
# REST API Request Tests - Alert Definitions and Alert Definition Profiles
#
# Alert Definitions primary collections:
#   /api/alert_definitions
#   /api/alert_definition_profiles
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
      "resources" => a_collection_containing_exactly(
        {
          "href" => a_string_matching(alert_definitions_url(alert_definitions[0].compressed_id))
        },
        {
          "href" => a_string_matching(alert_definitions_url(alert_definitions[1].compressed_id))
        }
      )
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
      "href"        => a_string_matching(alert_definitions_url(alert_definition.compressed_id)),
      "id"          => alert_definition.compressed_id,
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
    alert_definition = MiqAlert.find(ApplicationRecord.uncompress_id(response.parsed_body["results"].first["id"]))
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
                                :href    => alert_definitions_url(alert_definition.compressed_id))
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
      :expression  => { :eval_method => "mw_heap_used", :mode => "internal", :options => {} },
      :options     => { :notifications => {:delay_next_evaluation => 0, :evm_event => {} } },
      :enabled     => true
    }
    updated_options = { :notifications => {:delay_next_evaluation => 60, :evm_event => {} } }
    api_basic_authorize action_identifier(:alert_definitions, :edit, :resource_actions, :post)
    alert_definition = FactoryGirl.create(:miq_alert, sample_alert_definition)
    run_post(alert_definitions_url(alert_definition.id), gen_request(:edit, :options => updated_options))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["options"]).to eq(updated_options.deep_stringify_keys)
  end

  it "edits alert definitions" do
    api_basic_authorize collection_action_identifier(:alert_definitions, :edit)
    alert_definitions = FactoryGirl.create_list(:miq_alert, 2)
    run_post(alert_definitions_url, gen_request(:edit, [{"id"          => alert_definitions.first.id,
                                                         "description" => "Updated Test Alert 1"},
                                                        {"id"          => alert_definitions.second.id,
                                                         "description" => "Updated Test Alert 2"}]))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["results"].count).to eq(2)
    expect(alert_definitions.first.reload.description).to eq("Updated Test Alert 1")
    expect(alert_definitions.second.reload.description).to eq("Updated Test Alert 2")
  end
end

describe "Alerts Definition Profiles API" do
  it "forbids access to alert definition profiles list without an appropriate role" do
    api_basic_authorize
    run_get(alert_definition_profiles_url)

    expect(response).to have_http_status(:forbidden)
  end

  it "forbids access to an alert definition profile without an appropriate role" do
    api_basic_authorize
    alert_definition_profile = FactoryGirl.create(:miq_alert_set)
    run_get(alert_definition_profiles_url(alert_definition_profile.id))

    expect(response).to have_http_status(:forbidden)
  end

  it "reads 2 alert definition profiles as a collection" do
    api_basic_authorize collection_action_identifier(:alert_definition_profiles, :read, :get)
    alert_definition_profiles = FactoryGirl.create_list(:miq_alert_set, 2)
    run_get(alert_definition_profiles_url)

    expect(response).to have_http_status(:ok)
    expect_query_result(:alert_definition_profiles, 2, 2)
    expect_result_resources_to_include_hrefs(
      "resources",
      [alert_definition_profiles_url(alert_definition_profiles.first.compressed_id),
       alert_definition_profiles_url(alert_definition_profiles.second.compressed_id)]
    )
  end

  it "reads an alert definition profile as a resource" do
    api_basic_authorize action_identifier(:alert_definition_profiles, :read, :resource_actions, :get)
    alert_definition_profile = FactoryGirl.create(:miq_alert_set)
    run_get(alert_definition_profiles_url(alert_definition_profile.id))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "href"        => a_string_matching(alert_definition_profiles_url(alert_definition_profile.compressed_id)),
      "description" => alert_definition_profile.description,
      "guid"        => alert_definition_profile.guid
    )
  end

  it "reads alert definitions subcollection of an alert definition profile" do
    api_basic_authorize

    alert_definitions = FactoryGirl.create_list(:miq_alert, 2)
    alert_definition_profile = FactoryGirl.create(:miq_alert_set, :alerts => alert_definitions)
    run_get "#{alert_definition_profiles_url}/#{alert_definition_profile.id}/alert_definitions", :expand => "resources"

    expect(response).to have_http_status(:ok)
    expect_result_resources_to_include_hrefs(
      "resources",
      ["#{alert_definition_profiles_url}/#{alert_definition_profile.compressed_id}/alert_definitions/#{alert_definitions.first.compressed_id}",
       "#{alert_definition_profiles_url}/#{alert_definition_profile.compressed_id}/alert_definitions/#{alert_definitions.first.compressed_id}"]
    )
  end

  it "reads alert definition profile with expanded alert definitions subcollection" do
    api_basic_authorize action_identifier(:alert_definition_profiles, :read, :resource_actions, :get)

    alert_definition = FactoryGirl.create(:miq_alert)
    alert_definition_profile = FactoryGirl.create(:miq_alert_set, :alerts => [alert_definition])
    run_get "#{alert_definition_profiles_url}/#{alert_definition_profile.id}", :expand => "alert_definitions"

    expect(response).to have_http_status(:ok)
    expect_single_resource_query(
      "name" => alert_definition_profile.name, "description" => alert_definition_profile.description, "guid" => alert_definition_profile.guid
    )
    expect(response.parsed_body["alert_definitions"].first).to include(
      "description" => alert_definition.description,
      "guid"        => alert_definition.guid
    )
  end

  it "creates an alert definition profile" do
    sample_alert_definition_profile = {
      "description" => "Test Alert Definition Profile",
      "mode"        => "ContainerNode",
    }
    api_basic_authorize collection_action_identifier(:alert_definition_profiles, :create)
    run_post(alert_definition_profiles_url, sample_alert_definition_profile)

    expect(response).to have_http_status(:ok)
    id = ApplicationRecord.uncompress_id(response.parsed_body["results"].first["id"])
    alert_definition_profile = MiqAlertSet.find(id)
    expect(alert_definition_profile).to be_truthy
    expect(response.parsed_body["results"].first).to include(
      "description" => sample_alert_definition_profile["description"],
      "mode"        => sample_alert_definition_profile["mode"]
    )
  end

  it "deletes an alert definition profile via POST" do
    api_basic_authorize action_identifier(:alert_definition_profiles, :delete, :resource_actions, :post)
    alert_definition_profile = FactoryGirl.create(:miq_alert_set)
    run_post(alert_definition_profiles_url(alert_definition_profile.id), gen_request(:delete))

    expect(response).to have_http_status(:ok)
    expect_single_action_result(:success => true,
                                :message => "alert_definition_profiles id: #{alert_definition_profile.id} deleting",
                                :href    => alert_definition_profiles_url(alert_definition_profile.compressed_id))
  end

  it "deletes an alert definition profile via DELETE" do
    api_basic_authorize action_identifier(:alert_definition_profiles, :delete, :resource_actions, :delete)
    alert_definition_profile = FactoryGirl.create(:miq_alert_set)
    run_delete(alert_definition_profiles_url(alert_definition_profile.id))

    expect(response).to have_http_status(:no_content)
    expect(MiqAlertSet.exists?(alert_definition_profile.id)).to be_falsey
  end

  it "deletes alert definition profiles" do
    api_basic_authorize collection_action_identifier(:alert_definition_profiles, :delete)
    alert_definition_profiles = FactoryGirl.create_list(:miq_alert_set, 2)
    run_post(alert_definition_profiles_url, gen_request(:delete, [{"id" => alert_definition_profiles.first.id},
                                                                  {"id" => alert_definition_profiles.second.id}]))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["results"].count).to eq(2)
  end

  it "edits alert definition profiles" do
    api_basic_authorize action_identifier(:alert_definition_profiles, :edit, :resource_actions, :post)
    alert_definition_profiles = FactoryGirl.create_list(:miq_alert_set, 2)
    run_post(alert_definition_profiles_url, gen_request(:edit,
                                                        [{"id"          => alert_definition_profiles.first.id,
                                                          "description" => "Updated Test Alert Profile 1"},
                                                         {"id"          => alert_definition_profiles.second.id,
                                                          "description" => "Updated Test Alert Profile 2"}]))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["results"].count).to eq(2)
    expect(alert_definition_profiles.first.reload.description).to eq("Updated Test Alert Profile 1")
    expect(alert_definition_profiles.second.reload.description).to eq("Updated Test Alert Profile 2")
  end
end

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

  context "alert_actions subcollection" do
    let(:alert) { FactoryGirl.create(:miq_alert_status) }
    let(:actions_subcollection_url) { "#{alerts_url(alert.id)}/alert_actions" }
    let(:assignee) { FactoryGirl.create(:user) }
    let(:expected_assignee) do
      {
        'results' => a_collection_containing_exactly(
          a_hash_including("assignee_id" => assignee.id)
        )
      }
    end

    it "forbids access to alerts actions subcolletion without an appropriate role" do
      FactoryGirl.create(
        :miq_alert_status_action,
        :miq_alert_status => alert,
        :user             => FactoryGirl.create(:user)
      )
      api_basic_authorize
      run_get(actions_subcollection_url)
      expect(response).to have_http_status(:forbidden)
    end

    it "reads an alert action as a sub collection under an alert" do
      api_basic_authorize subcollection_action_identifier(:alerts, :alert_actions, :read, :get)
      alert_action = FactoryGirl.create(
        :miq_alert_status_action,
        :miq_alert_status => alert,
        :user             => FactoryGirl.create(:user)
      )
      run_get(actions_subcollection_url)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "name"      => "alert_actions",
        "count"     => 1,
        "subcount"  => 1,
        "resources" => [
          {
            "href" => a_string_matching("#{alerts_url(alert.id)}/alert_actions/#{alert_action.id}")
          }
        ]
      )
    end

    it "forbids creation of an alert action under alerts without an appropriate role" do
      api_basic_authorize
      run_post(
        actions_subcollection_url,
        "action_type" => "comment",
        "comment"     => "comment text",
      )
      expect(response).to have_http_status(:forbidden)
    end

    it "creates an alert action under an alert" do
      attributes = {
        "action_type" => "comment",
        "comment"     => "comment text",
      }
      api_basic_authorize subcollection_action_identifier(:alerts, :alert_actions, :create, :post)
      run_post(actions_subcollection_url, attributes)
      expect(response).to have_http_status(:ok)
      expected = {
        "results" => [
          a_hash_including(attributes)
        ]
      }
      expect(response.parsed_body).to include(expected)
    end

    it "creates an alert action on the current user" do
      user = FactoryGirl.create(:user)
      attributes = {
        "action_type" => "comment",
        "comment"     => "comment text",
        "user_id"     => user.id # should be ignored
      }
      api_basic_authorize subcollection_action_identifier(:alerts, :alert_actions, :create, :post)
      run_post(actions_subcollection_url, attributes)
      expect(response).to have_http_status(:ok)
      expected = {
        "results" => [
          a_hash_including(attributes.merge("user_id" => User.current_user.id))
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(user.id).not_to eq(User.current_user.id)
    end

    it "create an assignment alert action reference by id" do
      attributes = {
        "action_type" => "assign",
        "assignee"    => { "id" => assignee.id }
      }
      api_basic_authorize subcollection_action_identifier(:alerts, :alert_actions, :create, :post)
      run_post(actions_subcollection_url, attributes)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected_assignee)
    end

    it "create an assignment alert action reference by href" do
      attributes = {
        "action_type" => "assign",
        "assignee"    => { "href" => users_url(assignee.id) }
      }
      api_basic_authorize subcollection_action_identifier(:alerts, :alert_actions, :create, :post)
      run_post(actions_subcollection_url, attributes)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected_assignee)
    end

    it "returns errors when creating an invalid alert" do
      api_basic_authorize subcollection_action_identifier(:alerts, :alert_actions, :create, :post)
      run_post(
        actions_subcollection_url,
        "action_type" => "assign",
      )
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to include_error_with_message(
        "Failed to add a new alert action resource - Assignee can't be blank"
      )
    end

    it "reads an alert action as a resource under an alert" do
      api_basic_authorize subcollection_action_identifier(:alerts, :alert_actions, :read, :get)
      user = FactoryGirl.create(:user)
      alert_action = FactoryGirl.create(
        :miq_alert_status_action,
        :miq_alert_status => alert,
        :user             => user
      )
      run_get("#{actions_subcollection_url}/#{alert_action.id}")
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "href"        => a_string_matching("#{alerts_url(alert.id)}/alert_actions/#{alert_action.id}"),
        "id"          => alert_action.id,
        "action_type" => alert_action.action_type,
        "user_id"     => user.id,
        "comment"     => alert_action.comment,
      )
    end
  end
end

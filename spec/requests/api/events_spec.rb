#
# REST API Request Tests - Events
#
# Event primary collection:
#   /api/events
#
# Event subcollection:
#   /api/policies/:id/events
#
describe ApiController do
  let(:miq_event_guid_list) { MiqEventDefinition.pluck(:guid) }

  def create_events(count)
    count.times { FactoryGirl.create(:miq_event_definition) }
  end

  context "Event collection" do
    it "query invalid event" do
      api_basic_authorize

      run_get events_url(999_999)

      expect_resource_not_found
    end

    it "query events with no events defined" do
      api_basic_authorize

      run_get events_url

      expect_empty_query_result(:events)
    end

    it "query events" do
      api_basic_authorize
      create_events(3)

      run_get events_url

      expect_query_result(:events, 3, 3)
      expect_result_resources_to_include_hrefs("resources",
                                               MiqEventDefinition.pluck(:id).collect { |id| /^.*#{events_url(id)}$/ })
    end

    it "query events in expanded form" do
      api_basic_authorize
      create_events(3)

      run_get events_url, :expand => "resources"

      expect_query_result(:events, 3, 3)
      expect_result_resources_to_include_data("resources", "guid" => :miq_event_guid_list)
    end
  end

  context "Event subcollection" do
    let(:policy)             { FactoryGirl.create(:miq_policy, :name => "Policy 1") }
    let(:policy_url)         { policies_url(policy.id) }
    let(:policy_events_url)  { "#{policy_url}/events" }

    def relate_events_to(policy)
      MiqEventDefinition.all.collect(&:id).each do |event_id|
        MiqPolicyContent.create(:miq_policy_id => policy.id, :miq_event_definition_id => event_id)
      end
    end

    it "query events with no events defined" do
      api_basic_authorize

      run_get policy_events_url

      expect_empty_query_result(:events)
    end

    it "query events" do
      api_basic_authorize
      create_events(3)
      relate_events_to(policy)

      run_get policy_events_url, :expand => "resources"

      expect_query_result(:events, 3, 3)
      expect_result_resources_to_include_data("resources", "guid" => :miq_event_guid_list)
    end

    it "query policy with expanded events" do
      api_basic_authorize
      create_events(3)
      relate_events_to(policy)

      run_get policy_url, :expand => "events"

      expect_single_resource_query("name" => policy.name, "description" => policy.description, "guid" => policy.guid)
      expect_result_resources_to_include_data("events", "guid" => :miq_event_guid_list)
    end
  end
end

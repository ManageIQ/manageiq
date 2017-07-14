
# REST API Request Tests - Event Streams
#
# Event primary collection:
#   /api/event_streams
#
#
describe "Events API" do
  let(:event_stream_list) { EventStream.pluck(:id) }

  def create_events(count)
    count.times { FactoryGirl.create(:event_stream) }
  end

  context "Event Stream collection" do
    it "query invalid event_stream" do
      api_basic_authorize action_identifier(:event_streams, :read, :resource_actions, :get)

      run_get event_streams_url(999_999)

      expect(response).to have_http_status(:not_found)
    end

    it "query event_streams with no entries defined" do
      api_basic_authorize collection_action_identifier(:event_streams, :read, :get)

      run_get event_streams_url

      expect_empty_query_result(:event_streams)
    end

    it "query event_streams" do
      api_basic_authorize collection_action_identifier(:event_streams, :read, :get)
      create_events(3)

      run_get event_streams_url

      expect_query_result(:event_streams, 3, 3)
      expect_result_resources_to_include_hrefs("resources",
                                               EventStream.pluck(:id).collect { |id| /^.*#{event_streams_url(id)}$/ })
    end

    it "query event_streams in expanded form" do
      api_basic_authorize collection_action_identifier(:event_streams, :read, :get)
      create_events(3)

      run_get event_streams_url, :expand => "resources"

      expect_query_result(:event_streams, 3, 3)
    end
  end
end

# Rest API Request Tests - Queue specs
#
# - Creating a queue entry (put)         /api/queue                           POST
#
RSpec.describe "queue API" do
  let(:sample_queue_request) { {:method_name => "some_method", :args => ["arg_1", "arg_2"], } }

  describe "queue create" do
    it "supports single queue entry creation" do
      expected = {
        "id" => a_kind_of(Integer),
        "args" => ["arg_1", "arg_2"],
        "method_name" => "some_method"
      }

      api_basic_authorize collection_action_identifier(:queue, :create)

      run_post(queue_url, sample_queue_request)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["results"].first).to a_hash_including(expected)

      queue_id = response.parsed_body["results"].first["id"]
      expect(MiqQueue.exists?(queue_id)).to be_truthy
    end
  end
end

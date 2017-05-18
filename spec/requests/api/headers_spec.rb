RSpec.describe "Headers" do
  describe "Accept" do
    it "returns JSON when set to application/json" do
      api_basic_authorize

      get entrypoint_url, :headers => headers.merge("Accept" => "application/json")

      expect(response.parsed_body).to include("name" => "API", "description" => "REST API")
      expect(response).to have_http_status(:ok)
    end

    it "returns JSON when not provided" do
      api_basic_authorize

      get entrypoint_url, :headers => headers

      expect(response.parsed_body).to include("name" => "API", "description" => "REST API")
      expect(response).to have_http_status(:ok)
    end

    it "responds with an error for unsupported mime-types" do
      api_basic_authorize

      get entrypoint_url, :headers => headers.merge("Accept" => "application/xml")

      expected = {
        "error" => a_hash_including(
          "kind"    => "unsupported_media_type",
          "message" => "Invalid Response Format application/xml requested",
          "klass"   => "Api::UnsupportedMediaTypeError"
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:unsupported_media_type)
    end
  end

  describe "Content-Type" do
    it "accepts JSON by default" do
      api_basic_authorize(collection_action_identifier(:groups, :create))

      post groups_url, :params => '{"description": "foo"}', :headers => headers

      expect(response).to have_http_status(:ok)
    end

    it "will accept JSON when set to application/json" do
      api_basic_authorize(collection_action_identifier(:groups, :create))

      post(groups_url,
           :params  => '{"description": "foo"}',
           :headers => headers.merge("Content-Type" => "application/json"))

      expect(response).to have_http_status(:ok)
    end

    it "will ignore the Content-Type" do
      api_basic_authorize(collection_action_identifier(:groups, :create))

      post(groups_url,
           :params  => '{"description": "foo"}',
           :headers => headers.merge("Content-Type" => "application/xml"))

      expect(response).to have_http_status(:ok)
    end
  end
end

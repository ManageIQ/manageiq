#
# REST API Request Tests - /api versioning
#
describe "Versioning" do
  context "Versioning Queries" do
    it "test versioning query" do
      api_basic_authorize

      run_get entrypoint_url

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(name description version versions collections))
    end

    it "test query with a valid version" do
      api_basic_authorize

      # Let's get the versions
      run_get entrypoint_url

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(versions))

      versions = response.parsed_body["versions"]

      # Let's get the first version identifier
      expect(versions).to_not be_nil
      expect(versions[0]).to_not be_nil

      ver = versions[0]
      expect(ver).to have_key("href")

      ident = ver["href"].split("/").last

      # Let's try to access that version API URL
      run_get "#{entrypoint_url}/#{ident}"

      expect(response).to have_http_status(:ok)
      expect_result_to_have_keys(%w(name description version versions collections))
    end

    it "test query with an invalid version" do
      api_basic_authorize

      run_get "#{entrypoint_url}/v9999.9999"

      expect(response).to have_http_status(:bad_request)
    end
  end
end

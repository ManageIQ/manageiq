describe 'Middleware Datasources API' do
  let(:datasource) { FactoryGirl.create(:middleware_datasource) }

  # For some reason middleware_datasources_url is not returning the full
  # url, just the path portion. This is a hack, but will do the trick.
  def datasource_url
    "http://www.example.com#{middleware_datasources_url(datasource.id)}"
  end

  def match_id
    eq ApplicationRecord.compress_id(datasource.id).to_s
  end

  describe '/' do
    it 'forbids access without an appropriate role' do
      api_basic_authorize

      run_get middleware_datasources_url

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns an empty listing of datasources' do
      api_basic_authorize collection_action_identifier(:middleware_datasources, :read, :get)

      run_get middleware_datasources_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'name'      => 'middleware_datasources',
        'count'     => 0,
        'resources' => [],
        'subcount'  => 0
      )
    end

    it 'returns a a listing of datasources' do
      datasource

      api_basic_authorize collection_action_identifier(:middleware_datasources, :read, :get)

      run_get middleware_datasources_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'name'      => 'middleware_datasources',
        'count'     => 1,
        'resources' => [{
          'href' => datasource_url
        }],
        'subcount'  => 1
      )
    end
  end

  describe '/:id' do
    it 'returns the attributes of one datasource' do
      api_basic_authorize

      run_get middleware_datasources_url(datasource.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to match_id
      expect(response.parsed_body).to include('href' => datasource_url)
    end
  end
end

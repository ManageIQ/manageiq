describe 'Middleware Servers API' do
  let(:server) { FactoryGirl.create(:middleware_server) }

  # For some reason middleware_servers_url is not returning the full
  # url, just the path portion. This is a hack, but will do the trick.
  def server_url
    "http://www.example.com#{middleware_servers_url(server.id)}"
  end

  describe '/' do
    it 'forbids access without an appropriate role' do
      api_basic_authorize

      run_get middleware_servers_url

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns an empty listing of servers' do
      api_basic_authorize collection_action_identifier(:middleware_servers, :read, :get)

      run_get middleware_servers_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'name'      => 'middleware_servers',
        'count'     => 0,
        'resources' => [],
        'subcount'  => 0
      )
    end

    it 'returns a a listing of servers' do
      server

      api_basic_authorize collection_action_identifier(:middleware_servers, :read, :get)

      run_get middleware_servers_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'name'      => 'middleware_servers',
        'count'     => 1,
        'resources' => [{
          'href' => server_url
        }],
        'subcount'  => 1
      )
    end
  end

  describe '/:id' do
    it 'returns the attributes of one server' do
      api_basic_authorize

      run_get middleware_servers_url(server.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'href'       => server_url,
        'id'         => server.id.to_s,
        'name'       => server.name,
        'feed'       => server.feed,
        'properties' => server.properties,
      )
    end
  end
end

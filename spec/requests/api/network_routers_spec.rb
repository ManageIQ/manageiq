RSpec.describe 'NetworkRouters API' do
  describe 'GET /api/network_routers' do
    it 'lists all cloud subnets with an appropriate role' do
      network_router = FactoryGirl.create(:network_router)
      api_basic_authorize collection_action_identifier(:network_routers, :read, :get)
      run_get(network_routers_url)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'network_routers',
        'resources' => [
          hash_including('href' => a_string_matching(network_routers_url(network_router.compressed_id)))
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'forbids access to cloud subnets without an appropriate role' do
      api_basic_authorize
      run_get(network_routers_url)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/network_routers/:id' do
    it 'will show a cloud subnet with an appropriate role' do
      network_router = FactoryGirl.create(:network_router)
      api_basic_authorize action_identifier(:network_routers, :read, :resource_actions, :get)
      run_get(network_routers_url(network_router.id))
      expect(response.parsed_body).to include('href' => a_string_matching(network_routers_url(network_router.compressed_id)))
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to a cloud tenant without an appropriate role' do
      network_router = FactoryGirl.create(:network_router)
      api_basic_authorize
      run_get(network_routers_url(network_router.id))
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/network_routers' do
    it 'forbids access to network routers without an appropriate role' do
      api_basic_authorize
      run_post(network_routers_url, gen_request(:query, ""))
      expect(response).to have_http_status(:forbidden)
    end
  end
end

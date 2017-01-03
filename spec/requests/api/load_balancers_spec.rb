RSpec.describe 'LoadBalancers API' do
  describe 'GET /api/load_balancers' do
    it 'lists all load balancers with an appropriate role' do
      load_balancer = FactoryGirl.create(:load_balancer)
      api_basic_authorize collection_action_identifier(:load_balancers, :read, :get)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'load_balancers',
        'resources' => [
          hash_including('href' => a_string_matching(load_balancers_url(load_balancer.id)))
        ]
      }
      run_get(load_balancers_url)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'forbids access to load balancers without an appropriate role' do
      api_basic_authorize

      run_get(load_balancers_url)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/load_balancers/:id' do
    it 'will show a load balancer with an appropriate role' do
      load_balancer = FactoryGirl.create(:load_balancer)
      api_basic_authorize action_identifier(:load_balancers, :read, :resource_actions, :get)

      run_get(load_balancers_url(load_balancer.id))

      expect(response.parsed_body).to include('href' => a_string_matching(load_balancers_url(load_balancer.id)))
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to a load balancer without an appropriate role' do
      load_balancer = FactoryGirl.create(:load_balancer)
      api_basic_authorize

      run_get(load_balancers_url(load_balancer.id))

      expect(response).to have_http_status(:forbidden)
    end
  end
end

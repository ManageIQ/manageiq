RSpec.describe 'CloudSubnets API' do
  describe 'GET /api/cloud_subnets' do
    it 'lists all cloud subnets with an appropriate role' do
      cloud_subnet = FactoryGirl.create(:cloud_subnet)
      api_basic_authorize collection_action_identifier(:cloud_subnets, :read, :get)
      run_get(cloud_subnets_url)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'cloud_subnets',
        'resources' => [
          hash_including('href' => a_string_matching(cloud_subnets_url(cloud_subnet.id)))
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'forbids access to cloud subnets without an appropriate role' do
      api_basic_authorize

      run_get(cloud_subnets_url)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/cloud_subnets/:id' do
    it 'will show a cloud subnet with an appropriate role' do
      cloud_subnet = FactoryGirl.create(:cloud_subnet)
      api_basic_authorize action_identifier(:cloud_subnets, :read, :resource_actions, :get)

      run_get(cloud_subnets_url(cloud_subnet.id))

      expect(response.parsed_body).to include('href' => a_string_matching(cloud_subnets_url(cloud_subnet.id)))
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to a cloud tenant without an appropriate role' do
      cloud_subnet = FactoryGirl.create(:cloud_subnet)
      api_basic_authorize

      run_get(cloud_subnets_url(cloud_subnet.id))

      expect(response).to have_http_status(:forbidden)
    end
  end
end

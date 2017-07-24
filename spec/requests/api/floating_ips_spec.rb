RSpec.describe 'FloatingIp API' do
  describe 'GET /api/floating_ips' do
    it 'lists all cloud subnets with an appropriate role' do
      floating_ip = FactoryGirl.create(:floating_ip)
      api_basic_authorize collection_action_identifier(:floating_ips, :read, :get)
      run_get(floating_ips_url)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'floating_ips',
        'resources' => [
          hash_including('href' => a_string_matching(floating_ips_url(floating_ip.id)))
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'forbids access to cloud subnets without an appropriate role' do
      api_basic_authorize

      run_get(floating_ips_url)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/floating_ips/:id' do
    it 'will show a cloud subnet with an appropriate role' do
      floating_ip = FactoryGirl.create(:floating_ip)
      api_basic_authorize action_identifier(:floating_ips, :read, :resource_actions, :get)

      run_get(floating_ips_url(floating_ip.id))

      expect(response.parsed_body).to include('href' => a_string_matching(floating_ips_url(floating_ip.id)))
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to a cloud tenant without an appropriate role' do
      floating_ip = FactoryGirl.create(:floating_ip)
      api_basic_authorize

      run_get(floating_ips_url(floating_ip.id))

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/floating_ips' do
    it 'forbids access to floating ips without an appropriate role' do
      api_basic_authorize
      run_post(floating_ips_url, gen_request(:query, ""))
      expect(response).to have_http_status(:forbidden)
    end
  end
end

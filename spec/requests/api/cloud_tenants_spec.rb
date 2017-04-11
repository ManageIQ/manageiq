RSpec.describe 'CloudTenants API' do
  describe 'GET /api/cloud_tenants' do
    it 'lists all cloud tenants with an appropriate role' do
      cloud_tenant = FactoryGirl.create(:cloud_tenant)
      api_basic_authorize collection_action_identifier(:cloud_tenants, :read, :get)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'cloud_tenants',
        'resources' => [
          hash_including('href' => a_string_matching(cloud_tenants_url(cloud_tenant.id)))
        ]
      }
      run_get(cloud_tenants_url)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'forbids access to cloud tenants without an appropriate role' do
      api_basic_authorize

      run_get(cloud_tenants_url)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/cloud_tenants/:id' do
    it 'will show a cloud tenant with an appropriate role' do
      cloud_tenant = FactoryGirl.create(:cloud_tenant)
      api_basic_authorize action_identifier(:cloud_tenants, :read, :resource_actions, :get)

      run_get(cloud_tenants_url(cloud_tenant.id))

      expect(response.parsed_body).to include('href' => a_string_matching(cloud_tenants_url(cloud_tenant.id)))
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to a cloud tenant without an appropriate role' do
      cloud_tenant = FactoryGirl.create(:cloud_tenant)
      api_basic_authorize

      run_get(cloud_tenants_url(cloud_tenant.id))

      expect(response).to have_http_status(:forbidden)
    end
  end
end

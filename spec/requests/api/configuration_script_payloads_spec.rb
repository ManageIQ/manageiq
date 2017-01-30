RSpec.describe 'Configuration Script Payloads API' do
  describe 'GET /api/configuration_script_payloads' do
    it 'lists all the configuration script payloads with an appropriate role' do
      script_payload = FactoryGirl.create(:configuration_script_payload)
      api_basic_authorize collection_action_identifier(:configuration_script_payloads, :read, :get)

      run_get(configuration_script_payloads_url)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'configuration_script_payloads',
        'resources' => [
          hash_including('href' => a_string_matching(configuration_script_payloads_url(script_payload.id)))
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to configuration script payloads without an appropriate role' do
      api_basic_authorize

      run_get(configuration_script_payloads_url)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/configuration_script_payloads/:id' do
    it 'will show an ansible script_payload with an appropriate role' do
      script_payload = FactoryGirl.create(:configuration_script_payload)
      api_basic_authorize action_identifier(:configuration_script_payloads, :read, :resource_actions, :get)

      run_get(configuration_script_payloads_url(script_payload.id))

      expect(response.parsed_body)
        .to include('href' => a_string_matching(configuration_script_payloads_url(script_payload.id)))
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to an ansible script_payload without an appropriate role' do
      script_payload = FactoryGirl.create(:configuration_script_payload)
      api_basic_authorize

      run_get(configuration_script_payloads_url(script_payload.id))

      expect(response).to have_http_status(:forbidden)
    end
  end
end

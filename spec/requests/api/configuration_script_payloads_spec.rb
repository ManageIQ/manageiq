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

  describe 'GET /api/configuration_script_payloads/:id/authentications' do
    it 'returns the configuration script sources authentications' do
      authentication = FactoryGirl.create(:authentication)
      playbook = FactoryGirl.create(:configuration_script_payload, :authentications => [authentication])
      api_basic_authorize subcollection_action_identifier(:configuration_script_payloads, :authentications, :read, :get)

      run_get("#{configuration_script_payloads_url(playbook.id)}/authentications", :expand => 'resources')

      expected = {
        'resources' => [
          a_hash_including('id' => authentication.id)
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end
  end

  describe 'POST /api/configuration_script_payloads/:id/authentications' do
    it 'requires a type when creating a new authentication' do
      ems = FactoryGirl.create(:ext_management_system)
      playbook = FactoryGirl.create(:configuration_script_payload, :manager => ems)
      api_basic_authorize subcollection_action_identifier(:configuration_script_payloads, :authentications, :create)

      run_post("#{configuration_script_payloads_url(playbook.id)}/authentications", :name => 'foo')

      expected = {
        'error' => a_hash_including(
          'message' => a_string_including('must supply a type')
        )
      }
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to include(expected)
    end

    it 'requires that the type support create_in_provider_queue' do
      ems = FactoryGirl.create(:ext_management_system)
      playbook = FactoryGirl.create(:configuration_script_payload, :manager => ems)
      api_basic_authorize subcollection_action_identifier(:configuration_script_payloads, :authentications, :create)

      run_post("#{configuration_script_payloads_url(playbook.id)}/authentications", :type => 'Authentication')

      expected = {
        'error' => a_hash_including(
          'message' => a_string_including('type not currently supported')
        )
      }
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to include(expected)
    end

    it 'creates a new authentication' do
      ems = FactoryGirl.create(:ext_management_system)
      playbook = FactoryGirl.create(:configuration_script_payload, :manager => ems)
      auth = FactoryGirl.create(:authentication)
      expect(Authentication).to receive(:create_in_provider_queue).with(ems.id, 'name' => auth.name).and_return(auth)
      api_basic_authorize subcollection_action_identifier(:configuration_script_payloads, :authentications, :create)

      run_post("#{configuration_script_payloads_url(playbook.id)}/authentications", :type => 'Authentication', :name => auth.name)

      expected = {
        'results' => [a_hash_including('id' => auth.id)]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end
  end

  describe 'GET /api/configuration_script_payloads/:id/authentications/:id' do
    it 'returns a specific authentication' do
      authentication = FactoryGirl.create(:authentication)
      playbook = FactoryGirl.create(:configuration_script_payload, :authentications => [authentication])
      api_basic_authorize subcollection_action_identifier(:configuration_script_payloads, :authentications, :read, :get)

      run_get("#{configuration_script_payloads_url(playbook.id)}/authentications/#{authentication.id}")

      expected = {
        'id' => authentication.id
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end
  end
end

RSpec.describe 'Authentications API' do
  describe 'OPTIONS /api/authentications' do
    it 'will include fields for applicable classes' do
      api_basic_authorize

      run_options(authentications_url)

      test_klass = ManageIQ::Providers::AnsibleTower::AutomationManager::MachineCredential
      expected = {
        'fields' => a_hash_including(
          test_klass.to_s => test_klass.fields.deep_stringify_keys
        )
      }
      expect(response.parsed_body['data']).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end
end

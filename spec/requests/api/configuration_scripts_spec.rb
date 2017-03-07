RSpec.describe 'Configuration Scripts API' do
  describe 'GET /api/configuration_scripts/:id' do
    it 'will show a configuration script with an appropriate role' do
      configuration_script = FactoryGirl.create(:configuration_script)
      api_basic_authorize action_identifier(:configuration_scripts, :read, :resource_actions, :get)

      run_get(configuration_scripts_url(configuration_script.id))

      expect(response.parsed_body)
        .to include('href' => a_string_matching(configuration_scripts_url(configuration_script.id)))
    end

    it 'forbids access to a configuration script without an appropriate role' do
      configuration_script = FactoryGirl.create(:configuration_script)
      api_basic_authorize

      run_get(configuration_scripts_url(configuration_script.id))

      expect(response).to have_http_status(:forbidden)
    end
  end
end

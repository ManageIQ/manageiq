RSpec.describe 'Configuration Script Sources API' do
  describe 'GET /api/configuration_script_sources' do
    it 'lists all the configuration script sources with an appropriate role' do
      repository = FactoryGirl.create(:configuration_script_source)
      api_basic_authorize collection_action_identifier(:configuration_script_sources, :read, :get)

      run_get(configuration_script_sources_url)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'configuration_script_sources',
        'resources' => [hash_including('href' => a_string_matching(configuration_script_sources_url(repository.id)))]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to configuration script sources without an appropriate role' do
      api_basic_authorize

      run_get(configuration_script_sources_url)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/configuration_script_sources/:id' do
    it 'will show a configuration script source with an appropriate role' do
      repository = FactoryGirl.create(:configuration_script_source)
      api_basic_authorize collection_action_identifier(:configuration_script_sources, :read, :get)

      run_get(configuration_script_sources_url(repository.id))

      expected = {
        'href' => a_string_matching(configuration_script_sources_url(repository.id))
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to a configuration script source without an appropriate role' do
      repository = FactoryGirl.create(:configuration_script_source)
      api_basic_authorize

      run_get(configuration_script_sources_url(repository.id))

      expect(response).to have_http_status(:forbidden)
    end
  end
end

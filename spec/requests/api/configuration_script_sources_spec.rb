RSpec.describe 'Configuration Script Sources API' do
  let(:provider) { FactoryGirl.create(:ext_management_system) }
  let(:config_script_src) { FactoryGirl.create(:ansible_configuration_script_source, :manager => provider) }
  let(:config_script_src_2) { FactoryGirl.create(:ansible_configuration_script_source, :manager => provider) }

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

  describe 'POST /api/configuration_script_sources' do
    let(:params) do
      {
        :id          => config_script_src.id,
        :name        => 'foo',
        :description => 'bar'
      }
    end

    it 'will bulk update configuration_script_sources with an appropriate role' do
      api_basic_authorize collection_action_identifier(:configuration_script_sources, :edit, :post)
      params2 = params.dup.merge(:id => config_script_src_2.id)

      run_post(configuration_script_sources_url, :action => 'edit', :resources => [params, params2])

      expected = {
        'results' => [
          a_hash_including(
            'success' => true,
            'message' => "Updating Configuration Script Source with id #{config_script_src.id}",
            'task_id' => a_kind_of(Numeric)
          ),
          a_hash_including(
            'success' => true,
            'message' => "Updating Configuration Script Source with id #{config_script_src_2.id}",
            'task_id' => a_kind_of(Numeric)
          )
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'forbids updating configuration_script_sources without an appropriate role' do
      api_basic_authorize

      run_post(configuration_script_sources_url, :action => 'edit', :resources => [params])

      expect(response).to have_http_status(:forbidden)
    end

    it 'will delete multiple configuration script source with an appropriate role' do
      api_basic_authorize collection_action_identifier(:configuration_script_sources, :delete, :post)

      run_post(configuration_script_sources_url, :action => 'delete', :resources => [{:id => config_script_src.id}, {:id => config_script_src_2.id}])

      expected = {
        'results' => [
          a_hash_including(
            'success' => true,
            'message' => "Deleting Configuration Script Source with id #{config_script_src.id}",
            'task_id' => a_kind_of(Numeric)
          ),
          a_hash_including(
            'success' => true,
            'message' => "Deleting Configuration Script Source with id #{config_script_src_2.id}",
            'task_id' => a_kind_of(Numeric)
          )
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'forbids delete without an appropriate role' do
      api_basic_authorize

      run_post(configuration_script_sources_url, :action => 'delete', :resources => [{:id => config_script_src.id}])

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/configuration_script_sources/:id' do
    let(:params) do
      {
        :name        => 'foo',
        :description => 'bar'
      }
    end

    it 'updates a configuration_script_source with an appropriate role' do
      api_basic_authorize action_identifier(:configuration_script_sources, :edit)

      run_post(configuration_script_sources_url(config_script_src.id), :action => 'edit', :resource => params)

      expected = {
        'success' => true,
        'message' => "Updating Configuration Script Source with id #{config_script_src.id}",
        'task_id' => a_kind_of(Numeric)
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'forbids updating a configuration_script_source without an appropriate role' do
      api_basic_authorize

      run_post(configuration_script_sources_url(config_script_src.id), :action => 'edit', :resource => params)

      expect(response).to have_http_status(:forbidden)
    end

    it 'can delete a configuration_script_source with an appropriate role' do
      api_basic_authorize action_identifier(:configuration_script_sources, :delete)

      run_post(configuration_script_sources_url(config_script_src.id), :action => 'delete')

      expected = {
        'success' => true,
        'message' => "Deleting Configuration Script Source with id #{config_script_src.id}",
        'task_id' => a_kind_of(Numeric)
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'forbids configuration script source delete without an appropriate role' do
      api_basic_authorize

      run_post(configuration_script_sources_url(config_script_src.id), :action => 'delete')

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /api/configuration_script_sources/:id' do
    it 'can delete a configuration_script_source with an appropriate role' do
      api_basic_authorize action_identifier(:configuration_script_sources, :delete, :resource_actions, :delete)

      run_delete(configuration_script_sources_url(config_script_src.id))

      expect(response).to have_http_status(:no_content)
    end

    it 'forbids configuration_script_source delete without an appropriate role' do
      api_basic_authorize

      run_delete(configuration_script_sources_url(config_script_src.id))

      expect(response).to have_http_status(:forbidden)
    end
  end
end

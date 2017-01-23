RSpec.describe 'Ansible Repositories API' do
  describe 'GET /api/ansible_repositories' do
    it 'lists all the ansible repositories with an appropriate role' do
      repository = FactoryGirl.create(:ansible_configuration_script)
      api_basic_authorize collection_action_identifier(:ansible_repositories, :read, :get)

      run_get(ansible_repositories_url)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'ansible_repositories',
        'resources' =>
                       [hash_including('href' => a_string_matching(ansible_repositories_url(repository.id)))]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to ansible repositories without an appropriate role' do
      api_basic_authorize

      run_get(ansible_repositories_url)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/ansible_repositories/:id' do
    it 'will show an ansible repository with an appropriate role' do
      repository = FactoryGirl.create(:ansible_configuration_script)
      api_basic_authorize collection_action_identifier(:ansible_repositories, :read, :get)

      run_get(ansible_repositories_url(repository.id))

      expect(response.parsed_body).to include('href' => a_string_matching(ansible_repositories_url(repository.id)))
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to an ansible repository without an appropriate role' do
      repository = FactoryGirl.create(:ansible_configuration_script)
      api_basic_authorize

      run_get(ansible_repositories_url(repository.id))

      expect(response).to have_http_status(:forbidden)
    end
  end
end

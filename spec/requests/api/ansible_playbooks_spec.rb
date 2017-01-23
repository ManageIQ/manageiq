RSpec.describe 'Ansible Playbooks API' do
  describe 'GET /api/ansible_playbooks' do
    it 'lists all the ansible playbooks with an appropriate role' do
      playbook = FactoryGirl.create(:ansible_playbook)
      api_basic_authorize collection_action_identifier(:ansible_playbooks, :read, :get)

      run_get(ansible_playbooks_url)

      expected = {
        'count'     => 1,
        'subcount'  => 1,
        'name'      => 'ansible_playbooks',
        'resources' =>
                       [hash_including('href' => a_string_matching(ansible_playbooks_url(playbook.id)))]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to ansible playbooks without an appropriate role' do
      api_basic_authorize

      run_get(ansible_playbooks_url)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/ansible_playbooks/:id' do
    it 'will show an ansible playbook with an appropriate role' do
      playbook = FactoryGirl.create(:ansible_playbook)
      api_basic_authorize action_identifier(:ansible_playbooks, :read, :resource_actions, :get)

      run_get(ansible_playbooks_url(playbook.id))

      expect(response.parsed_body).to include('href' => a_string_matching(ansible_playbooks_url(playbook.id)))
      expect(response).to have_http_status(:ok)
    end

    it 'forbids access to an ansible playbook without an appropriate role' do
      playbook = FactoryGirl.create(:ansible_playbook)
      api_basic_authorize

      run_get(ansible_playbooks_url(playbook.id))

      expect(response).to have_http_status(:forbidden)
    end
  end
end

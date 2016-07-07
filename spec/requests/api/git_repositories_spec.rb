#
# Rest API Request Tests - Git Repositories specs
#
# - Creating                              /api/git_repositories                 POST
# - Creating a via action                 /api/git_repositories_url             action "create"
#
describe ApiController do
  CREDENTIALS_ATTR = ApiController::GitRepositories::CREDENTIALS_ATTR
  let(:dummy_url) { 'https://its.my/little/pony' }
  let(:expected_attributes) { %w(id name verify_ssl url) }
  let(:credentials) do
    {
      'verify_ssl' => 0,
      'userid'     => 'pink',
      'password'   => 'unicorn'
    }
  end
  let(:sample_git) do
    {
      'name' => 'Qilin',
      'url'  => dummy_url
    }
  end
  let(:sample_git_credentials) { sample_git.merge(CREDENTIALS_ATTR => credentials) }
  let(:git_repository) { FactoryGirl.create(:git_repository, :url => dummy_url) }
  let(:git_repository_url) { git_repositories_url(git_repository.id) }

  describe 'Git repository creation' do
    it 'rejects creation without appropriate role' do
      api_basic_authorize
      run_post(git_repositories_url, sample_git)

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects creation with id specified' do
      api_basic_authorize collection_action_identifier(:git_repositories, :create)
      run_post(git_repositories_url, sample_git.merge('id' => 1))

      expect_bad_request(/id or href should not be specified/i)
    end

    def expect_sample_git_creation_response
      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys('results', expected_attributes)
      expect_results_to_match_hash('results', [sample_git])
      expect(response_hash['results'].first['verify_ssl']).to eq(credentials['verify_ssl'])
      git_id = response_hash['results'].first['id']
      expect(GitRepository.exists?(git_id)).to be_truthy
      git = GitRepository.find(git_id)
      expect(git.authentications.size).to eq(1)
      expect(git.authentications[0].authtype).to eq('password')
      %w(userid password).each do |i|
        expect(git.authentications[0].send(i)).to eq(credentials[i])
      end
    end

    it 'supports single git repository creation' do
      api_basic_authorize collection_action_identifier(:git_repositories, :create)
      run_post(git_repositories_url, sample_git_credentials)
      expect_sample_git_creation_response
    end

    it 'supports single git repository creation via action' do
      api_basic_authorize collection_action_identifier(:git_repositories, :create)
      run_post(git_repositories_url, gen_request(:create, sample_git_credentials))
      expect_sample_git_creation_response
    end
    it 'supports single git repository creation without credentials' do
      api_basic_authorize collection_action_identifier(:git_repositories, :create)
      run_post(git_repositories_url, sample_git)
      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys('results', expected_attributes)
      expect_results_to_match_hash('results', [sample_git])
      expect(response_hash['results'].first['verify_ssl']).to eq(1)
      git_id = response_hash['results'].first['id']
      expect(GitRepository.exists?(git_id)).to be_truthy
      git = GitRepository.find(git_id)
      expect(git.authentications.size).to eq(0)
    end
  end

  describe 'Git Repository Refresh' do
    it 'fails to refresh on invalid git repository' do
      api_basic_authorize action_identifier(:git_repositories, :refresh)
      run_post(git_repositories_url(999_999), gen_request(:refresh))
      expect(response).to have_http_status(:not_found)
    end

    it 'fails when user lacks appropriate role' do
      api_basic_authorize
      run_post(git_repository_url, gen_request(:refresh))
      expect(response).to have_http_status(:forbidden)
    end

    it 'pushes a refresh task to queue' do
      api_basic_authorize action_identifier(:git_repositories, :refresh)
      run_post(git_repository_url, gen_request(:refresh))
      expect_single_action_result(:success => true,
                                  :task    => true,
                                  :message => "Refreshing Git: #{dummy_url}")
    end
  end

  describe 'Git Repository deletion' do
    it 'rejects deletion without appropriate role' do
      api_basic_authorize
      run_delete(git_repository_url)
      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects deletion without appropriate role' do
      api_basic_authorize
      run_post(git_repository_url, gen_request(:delete))
      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects deletion of invalid git repository' do
      api_basic_authorize action_identifier(:git_repositories, :delete)
      run_post(git_repositories_url(999_999), gen_request(:delete))
      expect(response).to have_http_status(:not_found)
    end

    context 'successful deletion of single git repository' do
      before(:each) { @git = FactoryGirl.create(:git_repository, :url => dummy_url) }

      it 'supports http post' do
        api_basic_authorize action_identifier(:git_repositories, :delete)
        run_post(git_repositories_url(@git.id), gen_request(:delete))
        expect_single_action_result(:success => true,
                                    :message => "Destroying Git: #{dummy_url}",
                                    :task    => true)
      end

      it 'supports http delete' do
        api_basic_authorize action_identifier(:git_repositories, :delete)
        run_delete(git_repositories_url(@git.id))
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end

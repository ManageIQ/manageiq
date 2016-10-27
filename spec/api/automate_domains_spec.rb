#
# REST API Request Tests - /api/automate_domains
#
describe "Automate Domains API" do
  describe 'refresh_from_source action' do
    let(:git_domain) { FactoryGirl.create(:miq_ae_git_domain) }
    it 'forbids access for users without proper permissions' do
      api_basic_authorize

      run_post(automate_domains_url(git_domain.id), gen_request(:refresh_from_source))

      expect(response).to have_http_status(:forbidden)
    end

    it 'fails to refresh git when the region misses git_owner role' do
      api_basic_authorize action_identifier(:automate_domains, :refresh_from_source)
      expect(GitBasedDomainImportService).to receive(:available?).and_return(false)

      run_post(automate_domains_url(git_domain.id), gen_request(:refresh_from_source))
      expect_single_action_result(:success => false,
                                  :message => 'Git owner role is not enabled to be able to import git repositories')
    end

    context 'with proper git_owner role' do
      let(:non_git_domain) { FactoryGirl.create(:miq_ae_domain) }
      before do
        expect(GitBasedDomainImportService).to receive(:available?).and_return(true)
      end

      it 'fails to refresh when domain did not originate from git' do
        api_basic_authorize action_identifier(:automate_domains, :refresh_from_source)

        run_post(automate_domains_url(non_git_domain.id), gen_request(:refresh_from_source))
        expect_single_action_result(
          :success => false,
          :message => a_string_matching(/Automate Domain .* did not originate from git repository/)
        )
      end

      it 'refreshes domain from git_repository' do
        api_basic_authorize action_identifier(:automate_domains, :refresh_from_source)

        expect_any_instance_of(GitBasedDomainImportService).to receive(:queue_refresh_and_import)
        run_post(automate_domains_url(git_domain.id), gen_request(:refresh_from_source))
        expect_single_action_result(
          :success => true,
          :message => a_string_matching(/Refreshing Automate Domain .* from git repository/),
          :href    => automate_domains_url(git_domain.id)
        )
      end

      it 'refreshes domain from git_repository by domain name' do
        api_basic_authorize action_identifier(:automate_domains, :refresh_from_source)

        expect_any_instance_of(GitBasedDomainImportService).to receive(:queue_refresh_and_import)
        run_post(automate_domains_url(git_domain.name), gen_request(:refresh_from_source))
        expect_single_action_result(
          :success => true,
          :message => a_string_matching(/Refreshing Automate Domain .* from git repository/),
          :href    => automate_domains_url(git_domain.name)
        )
      end
    end
  end
end

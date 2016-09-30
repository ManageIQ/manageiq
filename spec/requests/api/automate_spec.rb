#
# REST API Request Tests - /api/automate
#
describe "Automate API" do
  context "Automate Queries" do
    before(:each) do
      MiqAeDatastore.reset
      FactoryGirl.create(:miq_ae_domain, :name => "ManageIQ", :tenant_id => @group.tenant.id)
      FactoryGirl.create(:miq_ae_domain, :name => "Custom",   :tenant_id => @group.tenant.id)
      system_class = FactoryGirl.create(:miq_ae_class, :name => "System", :namespace => "Custom")
      FactoryGirl.create(:miq_ae_field, :name    => "on_entry", :class_id => system_class.id,
                                        :aetype  => "state",    :datatype => "string")
    end

    it "returns domains by default" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get automate_url

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "name"      => "automate",
        "subcount"  => 2,
        "resources" => a_collection_containing_exactly(
          a_hash_including("name" => "Custom",   "fqname" => "/Custom"),
          a_hash_including("name" => "ManageIQ", "fqname" => "/ManageIQ")
        )
      )
    end

    it "default to depth 0 for non-root queries" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get automate_url("custom")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match(
        [a_hash_including("name" => "Custom", "fqname" => "/Custom")]
      )
    end

    it "supports depth 1" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get(automate_url("custom"), :depth => 1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array(
        [a_hash_including("name" => "Custom", "fqname" => "/Custom",        "domain_fqname" => "/"),
         a_hash_including("name" => "System", "fqname" => "/Custom/System", "domain_fqname" => "/System")]
      )
    end

    it "supports depth -1" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get(automate_url, :depth => -1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array(
        [a_hash_including("name" => "ManageIQ", "fqname" => "/ManageIQ"),
         a_hash_including("name" => "Custom",   "fqname" => "/Custom"),
         a_hash_including("name" => "System",   "fqname" => "/Custom/System")]
      )
    end

    it "supports state_machines search option" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get(automate_url, :depth => -1, :search_options => "state_machines")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array(
        [a_hash_including("name" => "Custom",   "fqname" => "/Custom"),
         a_hash_including("name" => "System",   "fqname" => "/Custom/System")]
      )
    end

    it "always return the fqname" do
      api_basic_authorize action_identifier(:automate, :read, :collection_actions, :get)

      run_get(automate_url("custom/system"), :attributes => "name")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resources"]).to match_array([{"name" => "System", "fqname" => "/Custom/System"}])
    end
  end

  describe 'git_refresh action' do
    let(:git_domain) { FactoryGirl.create(:miq_ae_git_domain) }
    it 'forbids access for users without proper permissions' do
      api_basic_authorize

      run_post(automate_url(git_domain.id), gen_request(:git_refresh))

      expect(response).to have_http_status(:forbidden)
    end

    it 'fails to refresh git when the region misses git_owner role' do
      api_basic_authorize action_identifier(:automate, :git_refresh)
      expect(GitBasedDomainImportService).to receive(:available?).and_return(false)

      run_post(automate_url(git_domain.id), gen_request(:git_refresh))
      expect_single_action_result(:success => false,
                                  :message => 'Please enable the git owner role in order to import git repositories')
    end

    context 'with proper git_owner role' do
      let(:non_git_domain) { FactoryGirl.create(:miq_ae_domain) }
      before do
        expect(GitBasedDomainImportService).to receive(:available?).and_return(true)
      end

      it 'fails to refresh when domain did not originate from git' do
        api_basic_authorize action_identifier(:automate, :git_refresh)

        run_post(automate_url(non_git_domain.id), gen_request(:git_refresh))
        expect_single_action_result(:success => false,
                                    :message => "Domain [id=#{non_git_domain.id}] did not originate from git repository"
                                   )
      end

      it 'refreshes domain from git_repository' do
        api_basic_authorize action_identifier(:automate, :git_refresh)

        expect_any_instance_of(GitBasedDomainImportService).to receive(:import)
        run_post(automate_url(git_domain.id), gen_request(:git_refresh))
        expect_single_action_result(:success => true,
                                    :message => 'Domain refreshed from git repository',
                                    :href    => automate_url(git_domain.id)
                                   )
      end
    end
  end
end

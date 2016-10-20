describe MiqAeGitImport do
  context "#import" do
    before do
      EvmSpecHelper.local_guid_miq_server_zone
      @user = FactoryGirl.create(:user_with_group)
    end

    let(:miq_ae_git_import) { described_class.new(options) }
    let(:branch_name) { "b1" }
    let(:tag_name) { "t1" }
    let(:domain_name) { "BB8" }
    let(:url) { "http://www.example.com/x/y" }
    let(:domain) do
      FactoryGirl.create(:miq_ae_git_domain,
                         :tenant => @user.current_tenant,
                         :name   => domain_name)
    end
    let(:repo) { FactoryGirl.create(:git_repository, :url => url) }
    let(:branch_hash) do
      {'ref' => branch_name, 'ref_type' => MiqAeGitImport::BRANCH}
    end

    let(:tag_hash) do
      {'ref' => tag_name, 'ref_type' => MiqAeGitImport::TAG}
    end

    let(:branch) { FactoryGirl.create(:git_branch, :name => branch_name) }
    let(:tag) { FactoryGirl.create(:git_tag, :name => tag_name) }

    context "when the ref type and ref are valid" do
      let(:miq_ae_yaml_import_gitfs) { double("MiqAeYamlImportGitfs") }

      before do
        allow(GitRepository).to receive(:find).with(repo.id).and_return(repo)
        allow(repo).to receive(:refresh).and_return(nil)

        allow(MiqAeYamlImportGitfs).to receive(:new).with(domain_name, options).and_return(miq_ae_yaml_import_gitfs)
      end

      context "when there are branches returned" do
        let(:options) do
          {
            'domain'            => domain_name,
            'git_repository_id' => repo.id,
            'tenant_id'         => @user.current_tenant.id,
            'ref'               => branch_name
          }
        end

        before do
          allow(repo).to receive(:git_branches).and_return([branch])
        end

        it "imports correctly" do
          allow(miq_ae_yaml_import_gitfs).to receive(:import).and_return(domain)
          dom = miq_ae_git_import.import
          expect(dom.attributes).to have_attributes(branch_hash)
        end

        it "import fails with domain not found" do
          allow(miq_ae_yaml_import_gitfs).to receive(:import).and_return(nil)
          expect { miq_ae_git_import.import }.to raise_error(MiqAeException::DomainNotFound)
        end
      end

      context "when there are tags returned" do
        let(:options) do
          {
            'domain'            => domain_name,
            'git_repository_id' => repo.id,
            'tenant_id'         => @user.current_tenant.id,
            'ref'               => tag_name,
            'ref_type'          => MiqAeGitImport::TAG
          }
        end

        before do
          allow(repo).to receive(:git_tags).and_return([tag])
        end

        it "imports correctly" do
          allow(miq_ae_yaml_import_gitfs).to receive(:import).and_return(domain)
          dom = miq_ae_git_import.import
          expect(dom.attributes).to have_attributes(tag_hash)
        end
      end

      context "when a git_url and branch are given" do
        let(:options) do
          {
            'git_url'  => url,
            'ref'      => branch_name,
            'userid'   => 'fred',
            'password' => 'secret',
            'preview'  => false,
            'domain'   => domain_name
          }
        end

        before do
          allow(GitRepository).to receive(:find_or_create_by).with(:url => url).and_return(repo)
          allow(repo).to receive(:git_branches).and_return([branch])
        end

        it "imports correctly" do
          allow(miq_ae_yaml_import_gitfs).to receive(:import).and_return(domain)
          dom = miq_ae_git_import.import
          expect(dom.attributes).to have_attributes(branch_hash)
        end
      end
    end

    context "when the ref type and ref are not valid" do
      let(:options) { {'git_repository_id' => repo.id, 'ref_type' => ref_type, 'ref' => ref} }

      shared_examples_for "#import that has invalid ref or ref type" do
        it "throws an argument error" do
          expect { miq_ae_git_import.import }.to raise_error(ArgumentError)
        end
      end

      context "when the branch does not exist" do
        let(:ref) { 'branch does not exist' }
        let(:ref_type) { nil }

        it_behaves_like "#import that has invalid ref or ref type"
      end

      context "when the ref type is tag but the tag does not exist" do
        let(:ref) { 'tag does not exist' }
        let(:ref_type) { 'tag' }

        it_behaves_like "#import that has invalid ref or ref type"
      end

      context "when the ref type is invalid" do
        let(:ref_type) { "Invalid" }
        let(:ref) { "branch" }

        it_behaves_like "#import that has invalid ref or ref type"
      end
    end
  end
end

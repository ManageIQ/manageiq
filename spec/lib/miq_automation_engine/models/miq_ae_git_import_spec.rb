describe MiqAeGitImport do
  shared_context "variables" do
    let(:miq_ae_git_import) { described_class.new(options) }
    let(:branch_name) { "SomeBranch1" }
    let(:tag_name) { "SomeTag1" }
    let(:domain_name) { "BB8" }
    let(:url) { "http://www.example.com/x/y" }
    let(:domain) do
      FactoryGirl.create(:miq_ae_git_domain,
                         :tenant => user.current_tenant,
                         :name   => domain_name)
    end
    let(:repo) { FactoryGirl.create(:git_repository, :url => url) }
    let(:user) { FactoryGirl.create(:user_with_group) }
    let(:branch_hash) do
      {'ref' => branch_name, 'ref_type' => MiqAeGitImport::BRANCH}
    end

    let(:tag_hash) do
      {'ref' => tag_name, 'ref_type' => MiqAeGitImport::TAG}
    end

    let(:branch) { FactoryGirl.create(:git_branch, :name => branch_name) }
    let(:tag) { FactoryGirl.create(:git_tag, :name => tag_name) }
    let(:basic_options) do
      {
        'domain'    => domain_name,
        'tenant_id' => user.current_tenant.id
      }
    end
    let(:miq_ae_yaml_import_gitfs) { double("MiqAeYamlImportGitfs") }
    let(:new_repo_options) do
      {
        'userid'   => 'fred',
        'password' => 'secret',
        'preview'  => false
      }
    end
  end

  context "#import" do
    include_context "variables"
    before do
      EvmSpecHelper.local_guid_miq_server_zone
    end

    context "when the ref type and ref are valid" do
      before do
        allow(GitRepository).to receive(:find).with(repo.id).and_return(repo)
        allow(repo).to receive(:refresh).and_return(nil)
      end

      context "when there are branches returned" do
        let(:options) do
          basic_options.merge('ref' => branch_name, 'git_repository_id' => repo.id)
        end

        let(:import_options) do
          options.merge("ref_type" => MiqAeGitImport::BRANCH,
                        "branch"   => branch_name,
                        "git_dir"  => repo.directory_name)
        end

        before do
          allow(repo).to receive(:git_branches).and_return([branch])
        end

        shared_examples_for "#import that has a valid branch" do
          it "runs successfully" do
            expect(MiqAeYamlImportGitfs).to receive(:new).with(domain_name, import_options)
              .and_return(miq_ae_yaml_import_gitfs)
            allow(miq_ae_yaml_import_gitfs).to receive(:import).and_return(domain)
            dom = miq_ae_git_import.import
            expect(dom.attributes).to have_attributes(branch_hash)
          end
        end

        context "when the branch name is exact match" do
          it_behaves_like "#import that has a valid branch"
        end

        context "when the branch name is all lowercase" do
          let(:options) do
            basic_options.merge('ref' => branch_name.downcase, 'git_repository_id' => repo.id)
          end
          let(:import_options) do
            options.merge("ref_type" => MiqAeGitImport::BRANCH,
                          "ref"      => branch_name,
                          "branch"   => branch_name,
                          "git_dir"  => repo.directory_name)
          end
          it_behaves_like "#import that has a valid branch"
        end

        it "import fails with domain not found" do
          expect(MiqAeYamlImportGitfs).to receive(:new).with(domain_name, import_options)
            .and_return(miq_ae_yaml_import_gitfs)
          allow(miq_ae_yaml_import_gitfs).to receive(:import).and_return(nil)
          expect { miq_ae_git_import.import }.to raise_error(MiqAeException::DomainNotFound)
        end
      end

      context "when there are tags returned" do
        let(:options) do
          basic_options.reverse_merge('ref'               => tag_name,
                                      'git_repository_id' => repo.id,
                                      'ref_type'          => MiqAeGitImport::TAG)
        end

        let(:import_options) do
          options.merge("tag" => tag_name, "git_dir" => repo.directory_name)
        end

        before do
          allow(repo).to receive(:git_tags).and_return([tag])
        end

        shared_examples_for "#import that has a valid tag" do
          it "imports correctly" do
            expect(MiqAeYamlImportGitfs).to receive(:new).with(domain_name, import_options)
              .and_return(miq_ae_yaml_import_gitfs)
            allow(miq_ae_yaml_import_gitfs).to receive(:import).and_return(domain)
            dom = miq_ae_git_import.import
            expect(dom.attributes).to have_attributes(tag_hash)
          end
        end

        context "when the tag name is exact match" do
          it_behaves_like "#import that has a valid tag"
        end

        context "when the tag name is all lowercase" do
          let(:options) do
            basic_options.merge('ref'               => tag_name.downcase,
                                'git_repository_id' => repo.id,
                                'ref_type'          => MiqAeGitImport::TAG)
          end

          let(:import_options) do
            options.merge("tag" => tag_name, "ref" => tag_name, "git_dir" => repo.directory_name)
          end
          it_behaves_like "#import that has a valid tag"
        end
      end

      context "when a git_url and branch are given" do
        let(:options) do
          {'ref' => branch_name, 'git_url' => url}.merge(basic_options).merge(new_repo_options)
        end

        let(:import_options) do
          options.merge("branch"   => branch_name,
                        "ref_type" => MiqAeGitImport::BRANCH,
                        "git_dir"  => repo.directory_name)
        end

        before do
          allow(GitRepository).to receive(:find_or_create_by).with(:url => url).and_return(repo)
          allow(repo).to receive(:git_branches).and_return([branch])
        end

        it "imports correctly" do
          expect(MiqAeYamlImportGitfs).to receive(:new).with(domain_name, import_options)
            .and_return(miq_ae_yaml_import_gitfs)
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

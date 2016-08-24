describe MiqAeGitImport do
  before do
    EvmSpecHelper.local_guid_miq_server_zone
    @user = FactoryGirl.create(:user_with_group)
  end

  context "git import" do
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
      {'ref' => branch_name, 'ref_type' => MiqAeDomain::BRANCH}
    end

    let(:tag_hash) do
      {'ref' => tag_name, 'ref_type' => MiqAeDomain::TAG}
    end

    let(:branch) { FactoryGirl.create(:git_branch, :name => branch_name) }
    let(:tag) { FactoryGirl.create(:git_tag, :name => tag_name) }

    it "import a domain given a git repository and a branch" do
      domain_name = domain.name
      allow_any_instance_of(GitRepository).to receive(:refresh).with(no_args).and_return(nil)
      allow_any_instance_of(GitRepository).to receive(:git_branches).with(no_args).and_return([branch])
      allow_any_instance_of(MiqAeYamlImportGitfs).to receive(:import).with(any_args).and_return(domain)
      allow_any_instance_of(MiqAeYamlImportGitfs).to receive(:load_repo).with(any_args).and_return(nil)
      options = {'domain'            => domain_name,
                 'git_repository_id' => repo.id,
                 'tenant_id'         => @user.current_tenant.id,
                 'ref'               => branch_name}
      dom = MiqAeGitImport.new(options).import
      expect(dom.attributes).to have_attributes(branch_hash)
    end

    it "import a domain given a git repository and a tag" do
      domain_name = domain.name
      allow_any_instance_of(GitRepository).to receive(:refresh).with(no_args).and_return(nil)
      allow_any_instance_of(GitRepository).to receive(:git_tags).with(no_args).and_return([tag])
      allow_any_instance_of(MiqAeYamlImportGitfs).to receive(:import).with(any_args).and_return(domain)
      allow_any_instance_of(MiqAeYamlImportGitfs).to receive(:load_repo).with(any_args).and_return(nil)
      options = {'domain'            => domain_name,
                 'git_repository_id' => repo.id,
                 'tenant_id'         => @user.current_tenant.id,
                 'ref'               => tag_name,
                 'ref_type'          => 'tag'}

      dom = MiqAeGitImport.new(options).import
      expect(dom.attributes).to have_attributes(tag_hash)
    end

    it "import fails given a git repository and a tag" do
      domain_name = domain.name
      allow_any_instance_of(GitRepository).to receive(:refresh).with(no_args).and_return(nil)
      allow_any_instance_of(GitRepository).to receive(:git_tags).with(no_args).and_return([tag])
      allow_any_instance_of(MiqAeYamlImportGitfs).to receive(:import).with(any_args).and_return(nil)
      allow_any_instance_of(MiqAeYamlImportGitfs).to receive(:load_repo).with(any_args).and_return(nil)
      options = {'domain'            => domain_name,
                 'git_repository_id' => repo.id,
                 'tenant_id'         => @user.current_tenant.id,
                 'ref'               => tag_name,
                 'ref_type'          => 'tag'}

      expect { MiqAeGitImport.new(options).import }.to raise_error(MiqAeException::DomainNotFound)
    end

    it "import a domain given a git url and a branch" do
      options = {'git_url'   => url,
                 'tenant_id' => @user.current_tenant.id,
                 'ref'       => branch_name,
                 'userid'    => 'fred',
                 'password'  => 'secret',
                 'preview'   => false }
      allow_any_instance_of(GitRepository).to receive(:refresh).with(no_args).and_return(nil)
      allow_any_instance_of(GitRepository).to receive(:git_branches).with(no_args).and_return([branch])
      allow_any_instance_of(MiqAeYamlImportGitfs).to receive(:import).with(any_args).and_return(domain)
      allow_any_instance_of(MiqAeYamlImportGitfs).to receive(:load_repo).with(any_args).and_return(nil)

      dom = MiqAeGitImport.new(options).import
      expect(dom.attributes).to have_attributes(branch_hash)
    end

    it "non existent branch throws an exception" do
      options = {'git_repository_id' => repo.id,
                 'ref'               => 'Does not exist'}

      expect { MiqAeGitImport.new(options).import }.to raise_error(ArgumentError)
    end

    it "non existent tag throws an exception" do
      options = {'git_repository_id' => repo.id,
                 'ref'               => 'Does not exist',
                 'ref_type'          => 'tag'}

      expect { MiqAeGitImport.new(options).import }.to raise_error(ArgumentError)
    end

    it "invalid ref_type throws an exception" do
      options = {'git_repository_id' => repo.id,
                 'ref_type'          => 'Invalid',
                 'ref'               => 'branch'}

      expect { MiqAeGitImport.new(options).import }.to raise_error(ArgumentError)
    end
  end
end

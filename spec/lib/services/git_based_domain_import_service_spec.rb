describe GitBasedDomainImportService do
  shared_context "import setup" do
    let(:git_repo) do
      double("GitRepository", :git_branches => git_branches,
                              :id           => 123,
                              :url          => 'http://www.example.com')
    end
    let(:user) { double("User", :userid => userid, :id => 123) }
    let(:domain) { FactoryBot.build(:miq_ae_git_domain, :id => 999) }
    let(:userid) { "fred" }
    let(:task) { double("MiqTask", :id => 123) }
    let(:ref_name) { 'the_branch_name' }
    let(:ref_type) { 'branch' }
    let(:method_name) { 'import_git_repo' }
    let(:action) { 'Import git repository' }
    let(:task_options) { {:action => action, :userid => userid} }
    let(:queue_options) do
      {
        :class_name  => "MiqAeDomain",
        :method_name => method_name,
        :role        => "git_owner",
        :user_id     => 123,
        :args        => [import_options]
      }
    end
    let(:import_options) do
      {
        "git_repository_id" => git_repo.id,
        "ref"               => ref_name,
        "ref_type"          => ref_type,
        "tenant_id"         => 321,
        "overwrite"         => true
      }
    end
    let(:status) { "Ok" }
    let(:message) { "Success" }
  end

  shared_context "repository setup" do
    let(:git_branches) { [] }
    let(:queue_options) do
      {
        :class_name  => "GitRepository",
        :instance_id => git_repo.id,
        :method_name => method_name,
        :role        => "git_owner",
        :user_id     => 123,
        :args        => []
      }
    end
  end

  shared_context "domain setup" do
    let(:git_branches) { [] }
    let(:queue_options) do
      {
        :class_name  => "MiqAeDomain",
        :instance_id => domain.id,
        :method_name => method_name,
        :role        => "git_owner",
        :user_id     => 123,
        :args        => []
      }
    end
  end

  describe "#import" do
    include_context "import setup"
    before do
      allow(GitRepository).to receive(:find_by).with(:id => git_repo.id).and_return(git_repo)
      allow(domain).to receive(:update_attribute).with(:enabled, true)
      allow(MiqTask).to receive(:wait_for_taskid).with(task.id).and_return(task)
      allow(User).to receive(:current_user).and_return(user)
      allow(task).to receive(:message).and_return(nil)
    end

    context "when git branches that match the given name exist" do
      let(:git_branches) { [double("GitBranch", :name => ref_name)] }

      it "calls 'import' with the correct options" do
        allow(task).to receive(:task_results).and_return(domain)
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options).and_return(task.id)
        expect(domain).to receive(:update).with(:enabled => true)

        subject.import(git_repo.id, ref_name, 321)
      end
    end

    context "when git branches that match the given name do not exist" do
      let(:git_branches) { [] }
      let(:ref_name) { "the_tag_name" }
      let(:ref_type) { "tag" }

      it "calls 'import' with the correct options" do
        allow(task).to receive(:task_results).and_return(domain)
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options).and_return(task.id)
        expect(domain).to receive(:update).with(:enabled => true)
        subject.import(git_repo.id, ref_name, 321)
      end
    end

    context "when import fails and the task result is nil" do
      let(:git_branches) { [double("GitBranch", :name => ref_name)] }

      it "raises an exception with a message about invalid domain" do
        allow(task).to receive(:task_results).and_return(nil)
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

        expect { subject.import(git_repo.id, ref_name, 321) }.to raise_exception(
          MiqException::Error, "MiqException::Error"
        )
      end

      it "raises an exception with a message about multiple domains" do
        allow(task).to receive(:task_results).and_return(nil)
        allow(task).to receive(:message).and_return('multiple domains')
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

        expect { subject.import(git_repo.id, ref_name, 321) }.to raise_exception(
          MiqException::Error, 'multiple domains'
        )
      end
    end
  end

  describe "#queue_import" do
    include_context "import setup"
    before do
      allow(GitRepository).to receive(:find_by).with(:id => git_repo.id).and_return(git_repo)
      allow(User).to receive(:current_user).and_return(user)
      allow(task).to receive(:message).and_return(nil)
    end

    context "when git branches that match the given name exist" do
      let(:git_branches) { [double("GitBranch", :name => ref_name)] }

      it "calls 'queue_import' with the correct options" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

        expect(subject.queue_import(git_repo.id, ref_name, 321)).to eq(task.id)
      end
    end

    context "when git branches that match the given name do not exist" do
      let(:git_branches) { [] }
      let(:ref_name) { "the_tag_name" }
      let(:ref_type) { "tag" }

      it "calls 'queue_import' with the correct options" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

        expect(subject.queue_import(git_repo.id, ref_name, 321)).to eq(task.id)
      end
    end
  end

  describe "#queue_refresh_and_import" do
    include_context "import setup"
    before do
      allow(User).to receive(:current_user).and_return(user)
      allow(task).to receive(:message).and_return(nil)
    end

    let(:git_branches) { [] }
    let(:ref_name) { "the_tag_name" }
    let(:ref_type) { "tag" }
    let(:method_name) { 'import_git_url' }
    let(:action) { 'Refresh and import git repository' }

    context "when git branches that match the given name do not exist" do
      let(:import_options) do
        {
          "git_url"   => git_repo.url,
          "ref"       => ref_name,
          "ref_type"  => ref_type,
          "tenant_id" => 321,
          "overwrite" => true
        }
      end

      it "calls 'queue_import' with the correct options" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

        expect(subject.queue_refresh_and_import(git_repo.url, ref_name, ref_type, 321)).to eq(task.id)
      end
    end

    context "when auth args are provided" do
      let(:import_options) do
        {
          "git_url"    => git_repo.url,
          "ref"        => ref_name,
          "ref_type"   => ref_type,
          "tenant_id"  => 321,
          "overwrite"  => true,
          "userid"     => "bob",
          "verify_ssl" => false
        }
      end

      it "calls 'queue_import' with additional auth args using stringified keys" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

        expect(subject.queue_refresh_and_import(git_repo.url, ref_name, ref_type, 321, "userid" => "bob", :verify_ssl => false)).to eq(task.id)
      end
    end

    context "when a password is provided" do
      let(:import_options) do
        {
          "git_url"   => git_repo.url,
          "ref"       => ref_name,
          "ref_type"  => ref_type,
          "tenant_id" => 321,
          "overwrite" => true,
          "userid"    => "bob",
          "password"  => ManageIQ::Password.try_encrypt("secret")
        }
      end

      it "calls 'queue_import' with an encrypted password" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

        expect(subject.queue_refresh_and_import(git_repo.url, ref_name, ref_type, 321, "userid" => "bob", :password => "secret")).to eq(task.id)
      end
    end
  end

  describe "#queue_refresh" do
    include_context "import setup"
    include_context "repository setup"
    let(:action) { 'Refresh git repository' }
    let(:method_name) { 'refresh' }
    before do
      allow(User).to receive(:current_user).and_return(user)
    end

    it "calls 'queue_refresh' with the correct options" do
      expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

      expect(subject.queue_refresh(git_repo.id)).to eq(task.id)
    end
  end

  describe "#refresh" do
    include_context "import setup"
    include_context "repository setup"
    let(:action) { 'Refresh git repository' }
    let(:method_name) { 'refresh' }
    let(:task) { double("MiqTask", :id => 123, :status => status, :message => message) }

    before do
      allow(MiqTask).to receive(:wait_for_taskid).with(task.id).and_return(task)
      allow(MiqTask).to receive(:find).with(task.id).and_return(task)
      allow(User).to receive(:current_user).and_return(user)
    end

    context "success" do
      it "calls 'refresh' with the correct options and succeeds" do
        allow(task).to receive(:task_results).and_return(true)
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

        expect(subject.refresh(git_repo.id)).to be_truthy
      end
    end

    context "failure" do
      let(:status) { "Failed" }
      let(:message) { "My Error Message" }
      it "calls 'refresh' with the correct options and fails" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

        expect { subject.refresh(git_repo.id) }.to raise_exception(MiqException::Error, message)
      end
    end
  end

  describe "destroy domain" do
    include_context "import setup"
    include_context "domain setup"
    let(:action) { 'Destroy domain' }
    let(:method_name) { 'destroy' }
    let(:task) { double("MiqTask", :id => 123, :status => status, :message => message) }

    before do
      allow(MiqTask).to receive(:wait_for_taskid).with(task.id).and_return(task)
      allow(User).to receive(:current_user).and_return(user)
      allow(task).to receive(:task_results).and_return(true)
    end

    it "#destroy_domain" do
      expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

      expect(subject.destroy_domain(domain.id)).to be_truthy
    end

    it "#queue_destroy_domain" do
      expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options)).and_return(task.id)

      expect(subject.queue_destroy_domain(domain.id)).to eq(task.id)
    end
  end
end

describe GitBasedDomainImportService do
  shared_context "import setup" do
    let(:git_repo) { double("GitRepository", :git_branches => git_branches, :id => 123) }
    let(:user) { double("User", :userid => userid, :id => 123) }
    let(:domain) { FactoryGirl.build(:miq_ae_domain) }
    let(:userid) { "fred" }
    let(:task) { double("MiqTask", :id => 123) }
    let(:ref_name) { 'the_branch_name' }
    let(:ref_type) { 'branch' }
    let(:task_options) { {:action => "Import git repository", :userid => userid} }
    let(:queue_options) do
      {
        :class_name  => "MiqAeDomain",
        :method_name => "import_git_repo",
        :role        => "git_owner",
        :args        => [import_options]
      }
    end
    let(:import_options) do
      {
        "git_repository_id" => git_repo.id,
        "ref"               => ref_name,
        "ref_type"          => ref_type,
        "tenant_id"         => 321
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
    end

    context "when git branches that match the given name exist" do
      let(:git_branches) { [double("GitBranch", :name => ref_name)] }

      it "calls 'import' with the correct options" do
        allow(task).to receive(:task_results).and_return(domain)
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options).and_return(task.id)
        expect(domain).to receive(:update_attribute).with(:enabled, true)

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
        expect(domain).to receive(:update_attribute).with(:enabled, true)

        subject.import(git_repo.id, ref_name, 321)
      end
    end

    context "when import fails and the task result is nil" do
      let(:git_branches) { [double("GitBranch", :name => ref_name)] }

      it "raises exception" do
        allow(task).to receive(:task_results).and_return(nil)
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options).and_return(task.id)

        expect { subject.import(git_repo.id, ref_name, 321) }.to raise_exception(MiqException::Error)
      end
    end
  end

  describe "#queue_import" do
    include_context "import setup"
    before do
      allow(GitRepository).to receive(:find_by).with(:id => git_repo.id).and_return(git_repo)
      allow(User).to receive(:current_user).and_return(user)
    end

    context "when git branches that match the given name exist" do
      let(:git_branches) { [double("GitBranch", :name => ref_name)] }

      it "calls 'queue_import' with the correct options" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options).and_return(task.id)

        expect(subject.queue_import(git_repo.id, ref_name, 321)).to eq(task.id)
      end
    end

    context "when git branches that match the given name do not exist" do
      let(:git_branches) { [] }
      let(:ref_name) { "the_tag_name" }
      let(:ref_type) { "tag" }

      it "calls 'queue_import' with the correct options" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options).and_return(task.id)

        expect(subject.queue_import(git_repo.id, ref_name, 321)).to eq(task.id)
      end
    end
  end
end

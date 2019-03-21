describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource do
  let(:manager) do
    FactoryBot.create(:provider_embedded_ansible, :default_organization => 1).managers.first
  end

  # TODO:  Create a local repo instead... this will probably fail sporatically
  # using a live repo
  let(:params) do
    {
      :name    => "hello_world",
      :scm_url => "https://github.com/NickLaMuro/ansible-tower-samples"
    }
  end

  let(:repo_dir) { described_class::REPO_DIR }
  let(:repos)    { Dir.glob(File.join(repo_dir, "*")) }

  before do
    EvmSpecHelper.assign_embedded_ansible_role
  end

  # Clean up repo dir after each spec
  after do
    FileUtils.rm_rf(repos)
  end

  describe ".create_in_provider" do
    let(:notify_creation_args) { notification_args('creation') }

    context "with valid params" do
      it "creates a record and initializes a git repo" do
        expect(Notification).to receive(:create!).with(notify_creation_args)

        result = described_class.create_in_provider(manager.id, params)

        expect(result).to be_an(described_class)
        expect(result.scm_type).to eq("git")
        expect(result.scm_branch).to eq("master")
        expect(File).to exist(File.join(result.send(:repo_dir), ".git"))
      end
    end

    context "with invalid params" do
      it "does not create a record and does not call git" do
        params[:name]               = nil
        notify_creation_args[:type] = :tower_op_failure

        expect(AwesomeSpawn).to receive(:run!).never
        expect(Notification).to receive(:create!).with(notify_creation_args)

        expect do
          described_class.create_in_provider manager.id, params
        end.to raise_error(ActiveRecord::RecordInvalid)

        expect(repos).to be_empty
      end
    end
  end

  describe ".create_in_provider_queue" do
    it "creates a task and queue item" do
      EvmSpecHelper.local_miq_server
      task_id = described_class.create_in_provider_queue(manager.id, params)
      expect(MiqTask.find(task_id)).to have_attributes(:name => "Creating #{described_class::FRIENDLY_NAME} (name=#{params[:name]})")
      expect(MiqQueue.first).to have_attributes(
        :args        => [manager.id, params],
        :class_name  => described_class.name,
        :method_name => "create_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "embedded_ansible",
        :zone        => manager.my_zone
      )
    end
  end

  describe "#update_in_provider" do
    let(:update_params)      { { :scm_branch => "other_branch" } }
    let(:notify_update_args) { notification_args('update', update_params) }

    context "with valid params" do
      it "updates the record and initializes a git repo" do
        record   = build_record
        repo_dir = record.send(:repo_dir)

        expect(Notification).to receive(:create!).with(notify_update_args)

        result = record.update_in_provider update_params

        expect(result).to be_an(described_class)
        expect(result.scm_branch).to eq("other_branch")
        expect(File).to exist(File.join(repo_dir, ".git"))
      end
    end

    context "with invalid params" do
      it "does not create a record and does not call git" do
        record                    = build_record
        update_params[:scm_type]  = 'svn' # oh dear god...
        notify_update_args[:type] = :tower_op_failure

        expect(AwesomeSpawn).to receive(:run!).never
        expect(Notification).to receive(:create!).with(notify_update_args)

        expect do
          record.update_in_provider update_params
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe "#update_in_provider_queue" do
    it "creates a task and queue item" do
      record    = build_record
      task_id   = record.update_in_provider_queue({})
      task_name = "Updating #{described_class::FRIENDLY_NAME} (name=#{record.name})"

      expect(MiqTask.find(task_id)).to have_attributes(:name => task_name)
      expect(MiqQueue.first).to have_attributes(
        :instance_id => record.id,
        :args        => [{:task_id => task_id}],
        :class_name  => described_class.name,
        :method_name => "update_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "embedded_ansible",
        :zone        => manager.my_zone
      )
    end
  end

  describe "#delete_in_provider" do
    it "deletes the record and removes the git dir" do
      record   = build_record
      repo_dir = record.send(:repo_dir)

      expect(Notification).to receive(:create!).with(notification_args('deletion', {}))
      record.delete_in_provider

      expect { record.reload }.to raise_error ActiveRecord::RecordNotFound
      expect(File).to_not exist(repo_dir)
    end
  end

  describe "#delete_in_provider_queue" do
    it "creates a task and queue item" do
      record    = build_record
      task_id   = record.delete_in_provider_queue
      task_name = "Deleting #{described_class::FRIENDLY_NAME} (name=#{record.name})"

      expect(MiqTask.find(task_id)).to have_attributes(:name => task_name)
      expect(MiqQueue.first).to have_attributes(
        :instance_id => record.id,
        :args        => [],
        :class_name  => described_class.name,
        :method_name => "delete_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "embedded_ansible",
        :zone        => manager.my_zone
      )
    end
  end

  def build_record
    expect(Notification).to receive(:create!).with(any_args)
    described_class.create_in_provider manager.id, params
  end

  def notification_args(action, op_arg = params)
    {
      :type    => :tower_op_success,
      :options => {
        :op_name => "#{described_class::FRIENDLY_NAME} #{action}",
        :op_arg  => "(#{op_arg.except(:name).map { |k, v| "#{k}=#{v}" }.join(', ')})",
        :tower   => "EMS(manager_id=#{manager.id})"
      }
    }
  end
end

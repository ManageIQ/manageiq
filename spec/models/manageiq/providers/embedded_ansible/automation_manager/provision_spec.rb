describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Provision do
  let(:user) { FactoryBot.create(:user_with_group) }
  let(:manager) { FactoryBot.create(:provider_embedded_ansible, :default_organization => 1).managers.first }
  let(:playbook) { FactoryBot.create(:embedded_ansible_configuration_script, :manager => manager) }
  let(:request) { FactoryBot.create(:miq_provision_configuration_script_request, :requester => user, :source => playbook) }
  let(:provision) { described_class.create(:source => playbook, :miq_request => request, :userid => user.userid) }

  before do
    EvmSpecHelper.assign_embedded_ansible_role
  end

  describe "TASK_DESCRIPTION" do
    it "returns the correct task description" do
      expect(described_class::TASK_DESCRIPTION).to eq("Ansible Playbook Provision")
    end
  end

  describe "#run_provision" do
    it "signals provision" do
      expect(provision).to receive(:signal).with(:provision)
      provision.run_provision
    end
  end

  describe "#provision" do
    let(:job) { FactoryBot.create(:embedded_ansible_job, :ext_management_system => manager) }

    before do
      allow(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_stack).and_return(job)
      allow(provision).to receive(:connect_to_service!)
      allow(provision).to receive(:save!)
      allow(provision).to receive(:signal)
    end

    it "creates a stack with the correct options" do
      provision.options = {
        :become_enabled      => true,
        :credential_id       => 123,
        :execution_ttl       => 3600,
        :extra_vars          => {"key" => "value"},
        :hosts               => ["host1", "host2"],
        :vault_credential_id => 456,
        :verbosity           => 2
      }

      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_stack).with(
        playbook.parent,
        hash_including(
          :become_enabled      => true,
          :credential_id       => 123,
          :execution_ttl       => 3600,
          :extra_vars          => {"key" => "value"},
          :vault_credential_id => 456,
          :verbosity           => 2
        )
      ).and_return(job)

      provision.provision
    end

    it "defaults hosts to localhost if not provided" do
      provision.options = {}

      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_stack).with(
        playbook.parent,
        hash_including(:hosts => %w[localhost])
      ).and_return(job)

      provision.provision
    end

    it "stores the stack_id in phase_context" do
      provision.provision
      expect(provision.phase_context[:stack_id]).to eq(job.id)
    end

    it "connects the stack to the service" do
      expect(provision).to receive(:connect_to_service!).with(job, :name => "Provision")
      provision.provision
    end

    it "saves the provision" do
      expect(provision).to receive(:save!).at_least(:once)
      provision.provision
    end

    it "signals check_provisioned" do
      expect(provision).to receive(:signal).with(:check_provisioned)
      provision.provision
    end
  end

  describe "#check_provisioned" do
    let(:job) { FactoryBot.create(:embedded_ansible_job, :ext_management_system => manager) }

    before do
      provision.phase_context[:stack_id] = job.id
    end

    context "when the job is still running" do
      before do
        allow(provision).to receive(:running?).and_return(true)
      end

      it "requeues the phase" do
        expect(provision).to receive(:requeue_phase)
        provision.check_provisioned
      end
    end

    context "when the job is finished" do
      before do
        allow(provision).to receive(:running?).and_return(false)
      end

      it "signals post_provision" do
        expect(provision).to receive(:signal).with(:post_provision)
        provision.check_provisioned
      end
    end
  end

  describe "#post_provision" do
    let(:job) { FactoryBot.create(:embedded_ansible_job, :ext_management_system => manager) }

    before do
      provision.phase_context[:stack_id] = job.id
    end

    context "when the job succeeded" do
      before do
        allow(provision).to receive(:succeeded?).and_return(true)
      end

      it "signals mark_as_completed" do
        expect(provision).to receive(:signal).with(:mark_as_completed)
        provision.post_provision
      end
    end

    context "when the job failed" do
      before do
        allow(provision).to receive(:succeeded?).and_return(false)
      end

      it "calls abort_job with error message" do
        expect(provision).to receive(:abort_job).with("Failed to provision playbook", "error")
        provision.post_provision
      end
    end
  end

  describe "#abort_job" do
    it "updates parent with finished state and error status" do
      expect(provision).to receive(:update_and_notify_parent).with(
        :state   => "finished",
        :status  => "Error",
        :message => "Test error message"
      )
      provision.abort_job("Test error message", "error")
    end

    it "capitalizes the status" do
      expect(provision).to receive(:update_and_notify_parent).with(
        hash_including(:status => "Warn")
      )
      provision.abort_job("Test warning", "warn")
    end
  end

  describe "#running?" do
    let(:raw_status) { double("raw_status") }

    before do
      allow(provision).to receive(:stack).and_return(double("stack", :raw_status => raw_status))
    end

    it "returns true when the job is not completed" do
      allow(raw_status).to receive(:completed?).and_return(false)
      expect(provision.running?).to be true
    end

    it "returns false when the job is completed" do
      allow(raw_status).to receive(:completed?).and_return(true)
      expect(provision.running?).to be false
    end
  end

  describe "#succeeded?" do
    let(:raw_status) { double("raw_status") }

    before do
      allow(provision).to receive(:stack).and_return(double("stack", :raw_status => raw_status))
    end

    it "returns true when the job succeeded" do
      allow(raw_status).to receive(:succeeded?).and_return(true)
      expect(provision.succeeded?).to be true
    end

    it "returns false when the job failed" do
      allow(raw_status).to receive(:succeeded?).and_return(false)
      expect(provision.succeeded?).to be false
    end
  end

  describe "#mark_as_completed" do
    it "updates parent with finished state and completion message" do
      expect(provision).to receive(:update_and_notify_parent).with(
        :state   => "finished",
        :message => "Playbook provision is complete"
      )
      provision.mark_as_completed
    end

    it "signals finish" do
      allow(provision).to receive(:update_and_notify_parent)
      expect(provision).to receive(:signal).with(:finish)
      provision.mark_as_completed
    end
  end

  describe "#finish" do
    it "marks execution servers" do
      expect(provision).to receive(:mark_execution_servers)
      provision.finish
    end
  end

  describe "#stack_klass" do
    it "returns the correct Job class" do
      expect(provision.stack_klass).to eq(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job)
    end
  end

  describe "#stack" do
    let(:job) { FactoryBot.create(:embedded_ansible_job, :ext_management_system => manager) }

    before do
      provision.phase_context[:stack_id] = job.id
    end

    it "returns the stack from phase_context" do
      expect(provision.stack).to eq(job)
    end

    it "caches the stack" do
      stack1 = provision.stack
      stack2 = provision.stack
      expect(stack1.object_id).to eq(stack2.object_id)
    end
  end
end

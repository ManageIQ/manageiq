RSpec.describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook do
  let(:manager)               { FactoryBot.create(:embedded_automation_manager_ansible, :provider) }
  let(:ansible_script_source) { FactoryBot.create(:embedded_ansible_configuration_script_source, :manager_id => manager.id) }
  let(:playbook)              { FactoryBot.create(:embedded_playbook, :configuration_script_source => ansible_script_source) }

  before { EvmSpecHelper.assign_embedded_ansible_role }

  context "#run" do
    it "launches the referenced ansible playbook" do
      job = playbook.run(:execution_ttl => 100)

      expect(job).to be_a ManageIQ::Providers::AnsiblePlaybookWorkflow
      expect(job.options[:env_vars]).to eq({})
      expect(job.options[:extra_vars]).to eq({})
      expect(job.options[:configuration_script_source_id]).to eq(ansible_script_source.id)
      expect(job.options[:playbook_relative_path]).to eq(playbook.name)
      expect(job.options[:timeout]).to eq(100.minutes)
      expect(job.options[:verbosity]).to eq(0)
    end

    it "accepts different variables to launch a playbook against" do
      job = playbook.run(:extra_vars => {:some_key => :some_value})

      expect(job).to be_a ManageIQ::Providers::AnsiblePlaybookWorkflow
      expect(job.options[:env_vars]).to eq({})
      expect(job.options[:extra_vars]).to eq(:some_key => :some_value)
    end

    it "passes execution_ttl to the job as its timeout" do
      job = playbook.run(:execution_ttl => "5")

      expect(job).to be_a ManageIQ::Providers::AnsiblePlaybookWorkflow
      expect(job.options[:timeout]).to eq(5.minutes)
    end

    it "passes verbosity to the job when specified" do
      job = playbook.run(:verbosity => "5")

      expect(job).to be_a ManageIQ::Providers::AnsiblePlaybookWorkflow
      expect(job.options[:verbosity]).to eq(5)
    end

    it "passes become_enabled to the job when specified" do
      job = playbook.run(:become_enabled => true)

      expect(job).to be_a ManageIQ::Providers::AnsiblePlaybookWorkflow
      expect(job.options[:become_enabled]).to eq(true)
    end
  end

  context "#build_extra_vars" do
    it "merges external hashes to send out to ansible_runner" do
      external      = {:some_key => :some_value}
      merged        = playbook.send(:build_extra_vars, external)

      expect(merged).to eq(:some_key => :some_value)
    end

    it "merges all empty arguments to send out to the tower gem" do
      external      = nil
      merged        = playbook.send(:build_extra_vars, external)

      expect(merged).to eq({})
    end

    it "decrypts extra_vars before sending out to the tower gem" do
      password      = "password::#{ManageIQ::Password.encrypt("some_value")}"
      external      = {:some_key => password}
      merged        = playbook.send(:build_extra_vars, external)

      expect(merged).to eq(:some_key => "some_value")
    end
  end
end

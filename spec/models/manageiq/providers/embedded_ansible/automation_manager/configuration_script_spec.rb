describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript do
  let(:ansible_script_source)              { FactoryBot.create(:embedded_ansible_configuration_script_source) }
  let(:playbook)                           { FactoryBot.create(:embedded_playbook, :configuration_script_source => ansible_script_source) }
  let(:manager_with_configuration_scripts) { FactoryBot.create(:embedded_automation_manager_ansible, :provider, :configuration_script) }

  before do
    EvmSpecHelper.assign_embedded_ansible_role

    ansible_script_source.update(:manager_id => manager.id)
    manager_with_configuration_scripts.configuration_scripts.each do |cs|
      cs.parent_id = playbook.id
      cs.save
    end

    # Note:  For some unkown reason, this is required or the belongs_to specs
    # returns two result when calling manager.configuration_scripts for the
    # second time...
    manager_with_configuration_scripts.reload
  end

  # The following specs are copied from the 'ansible configuration_script' spec
  # helper from the AnsibleTower Provider repo, but have been modified to make
  # sense for the case of AnsibleRunner.  Previously was:
  #
  #     it_behaves_like 'ansible configuration_script'
  #
  # Below are `let` calls from there was well.
  #

  let(:manager) { manager_with_configuration_scripts }

  it "belongs_to the manager" do
    expect(manager.configuration_scripts.size).to eq 1
    expect(manager.configuration_scripts.first.variables).to eq :instance_ids => ['i-3434']
    expect(manager.configuration_scripts.first).to be_a ConfigurationScript
  end

  context "#run" do
    let(:cs) { manager.configuration_scripts.first }

    it "launches the referenced ansible job template" do
      job = cs.run

      expect(job).to be_a ManageIQ::Providers::AnsiblePlaybookWorkflow
      expect(job.options[:env_vars]).to eq({})
      expect(job.options[:extra_vars]).to eq(:instance_ids => ["i-3434"])
      expect(job.options[:configuration_script_source_id]).to eq(ansible_script_source.id)
      expect(job.options[:playbook_relative_path]).to eq(playbook.name)
      expect(job.options[:timeout]).to eq(1.hour)
      expect(job.options[:verbosity]).to eq(0)
    end

    it "accepts different variables to launch a job template against" do
      job = cs.run(:extra_vars => {:some_key => :some_value})

      expect(job).to be_a ManageIQ::Providers::AnsiblePlaybookWorkflow
      expect(job.options[:env_vars]).to eq({})
      expect(job.options[:extra_vars]).to eq(:instance_ids => ["i-3434"], :some_key => :some_value)
    end

    it "passes execution_ttl to the job as its timeout" do
      job = cs.run(:execution_ttl => "5")

      expect(job).to be_a ManageIQ::Providers::AnsiblePlaybookWorkflow
      expect(job.options[:timeout]).to eq(5.minutes)
    end

    it "passes verbosity to the job when specified" do
      job = cs.run(:verbosity => "5")

      expect(job).to be_a ManageIQ::Providers::AnsiblePlaybookWorkflow
      expect(job.options[:verbosity]).to eq(5)
    end

    it "passes become_enabled to the job when specified" do
      job = cs.run(:become_enabled => true)

      expect(job).to be_a ManageIQ::Providers::AnsiblePlaybookWorkflow
      expect(job.options[:become_enabled]).to eq(true)
    end
  end

  context "#merge_extra_vars" do
    it "merges internal and external hashes to send out to ansible_runner" do
      config_script = manager.configuration_scripts.first
      external      = {:some_key => :some_value}
      internal      = config_script.variables
      merged        = config_script.send(:merge_extra_vars, external)

      expect(internal).to be_a Hash
      expect(merged).to eq(:instance_ids => ["i-3434"], :some_key => :some_value)
    end

    it "merges an internal hash and an empty hash to send out to ansible_runner" do
      config_script = manager.configuration_scripts.first
      external      = nil
      merged        = config_script.send(:merge_extra_vars, external)

      expect(merged).to eq(:instance_ids => ["i-3434"])
    end

    it "merges an empty internal hash and a hash to send out to the tower gem" do
      config_script = manager.configuration_scripts.first.tap { |cs| cs.variables = {} }
      external      = {:some_key => :some_value}
      merged        = config_script.send(:merge_extra_vars, external)

      expect(merged).to eq(external)
    end

    it "merges all empty arguments to send out to the tower gem" do
      config_script = manager.configuration_scripts.first.tap { |cs| cs.variables = {} }
      external      = nil
      merged        = config_script.send(:merge_extra_vars, external)

      expect(merged).to eq({})
    end

    it "decrypts extra_vars before sending out to the tower gem" do
      config_script = manager.configuration_scripts.first
      password      = "password::#{ManageIQ::Password.encrypt("some_value")}"
      external      = {:some_key => password}
      merged        = config_script.send(:merge_extra_vars, external)

      expect(merged).to eq(:instance_ids => ["i-3434"], :some_key => "some_value")
    end
  end

  # was `context "CUD via the API"`
  context "CRUD operations" do
    let(:manager) { FactoryBot.create(:embedded_automation_manager_ansible, :provider) }

    let(:params) do
      {
        :description  => "Description",
        :extra_vars   => {}.to_json,
        :inventory_id => 1,
        :playbook     => playbook.name,
        :name         => "My Job Template",
        :related      => {}
      }
    end

    context ".create_in_provider" do
      it "successfully created in provider" do
        new_config_script = described_class.create_in_provider(manager.id, params)

        expect(new_config_script).to be_a(described_class)
        expect(new_config_script.manager_id).to eq(manager.id)
      end

      it "raises an error when the playbook does not exist from the script source" do
        params[:playbook] = "not_a_playbook.yaml"
        error_msg         = 'Playbook name="not_a_playbook.yaml" no longer exists'

        expect do
          described_class.create_in_provider(manager.id, params)
        end.to raise_error(RuntimeError, error_msg)
      end

      # TODO:  Determine if we want to have a uniqueness validation to
      # replicate this functionality, otherwise delete this case.
      #
      # context "provider raises on create" do
      #   it "with a string" do
      #     expect(AnsibleTowerClient::Connection).to receive(:new).and_return(atc)
      #     expect(job_templates).to receive(:create!).and_raise(AnsibleTowerClient::Error, "Job template with this Name already exists.")

      #     expect { described_class.create_in_provider(manager.id, params) }.to raise_error(AnsibleTowerClient::Error, "Job template with this Name already exists.")
      #   end
      # end
    end

    it ".create_in_provider_queue" do
      EvmSpecHelper.local_miq_server
      task_id = described_class.create_in_provider_queue(manager.id, params)

      expect(MiqTask.find(task_id)).to have_attributes(:name => "Creating #{described_class::FRIENDLY_NAME} (name=#{params[:name]})")
      expect(MiqQueue.first).to have_attributes(
        :args        => [manager.id, params],
        :class_name  => described_class.name,
        :method_name => "create_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "embedded_ansible",
        :zone        => nil
      )
    end

    it "#update_in_provider_queue" do
      project       = described_class.create!(:manager => manager, :name => "config_script.yml")
      task_id       = project.update_in_provider_queue(params)
      expected_args = params.tap { |p| p[:task_id] = task_id }

      expect(MiqTask.find(task_id)).to have_attributes(:name => "Updating #{described_class::FRIENDLY_NAME} (name=config_script.yml)")
      expect(MiqQueue.first).to have_attributes(
        :instance_id => project.id,
        :args        => [expected_args],
        :class_name  => described_class.name,
        :method_name => "update_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "embedded_ansible",
        :zone        => nil
      )
    end
  end
end

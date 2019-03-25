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
        :zone        => manager.zone.name
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
        :zone        => manager.my_zone
      )
    end
  end
end

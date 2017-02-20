require_migration

describe MigrateTowerJobStiTypeToAutomationManager do
  let(:job_stub) { migration_stub(:OrchestrationStack) }

  migration_context :up do
    it 'migrates Ansible Tower Jobs to be of AutomationManager type' do
      job = job_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job')

      migrate

      expect(job.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager::Job')
    end

    it 'will not migrate Jobs other than those of Ansible Tower ConfigurationManager' do
      job = job_stub.create!(:type => 'ManageIQ::Providers::SomeManager::Job')

      migrate

      expect(job.reload.type).to eq('ManageIQ::Providers::SomeManager::Job')
    end
  end

  migration_context :down do
    it 'migrates Ansible Tower AutomationManager Jobs to ConfigurationManager type' do
      job = job_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Job')

      migrate

      expect(job.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job')
    end
  end
end

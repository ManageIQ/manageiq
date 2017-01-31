require_migration

describe MigrateAnsibleTowerConfigurationManagerStiTypeToAutomationManager do
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it 'migrates Ansible Tower Configuration Manager to Automation Manager type' do
      configuration_manager = ems_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager')

      migrate

      expect(configuration_manager.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager')
    end

    it 'will not migrate other than Ansible Tower Configuration Manager' do
      some_mananger = ems_stub.create!(:type => 'ManageIQ::Providers::SomeManager')

      migrate

      expect(some_mananger.reload.type).to eq('ManageIQ::Providers::SomeManager')
    end
  end

  migration_context :down do
    it 'migrates Ansible Tower Automation Manager to Configuration Manager type' do
      automation_manager = ems_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager')

      migrate

      expect(automation_manager.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager')
    end
  end
end

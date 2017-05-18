require_migration

describe MigrateAnsibleTowerConfigurationManagerStiTypeToAutomationManager do
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }
  let(:configuration_script_stub) { migration_stub(:ConfigurationScript) }
  let(:configured_system_stub) { migration_stub(:ConfiguredSystem) }
  let(:job_stub) { migration_stub(:Job) }
  let(:inventory_group_stub) { migration_stub(:EmsFolder) }

  migration_context :up do
    context 'migrate_configuration_managers' do
      it 'migrates Ansible Tower ConfigurationManager and others to be of AutomationManager type' do
        manager = ems_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager')
        script = configuration_script_stub.create!(
          :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript'
        )
        system = configured_system_stub.create!(
          :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem'
        )
        job = job_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job')
        inventory_g = inventory_group_stub.create!(
          :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::InventoryGroup'
        )

        migrate

        expect(manager.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager')
        expect(script.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript')
        expect(system.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem')
        expect(job.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager::Job')
        expect(inventory_g.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager::InventoryGroup')
      end

      it 'will not migrate things other than those of Ansible Tower ConfigurationManager' do
        mananger = ems_stub.create!(:type => 'ManageIQ::Providers::SomeManager')
        script = configuration_script_stub.create!(:type => 'ManageIQ::Providers::SomeManager::ConfigurationScript')
        system = configured_system_stub.create!(:type => 'ManageIQ::Providers::SomeManager::ConfiguredSystem')
        job = configured_system_stub.create!(:type => 'ManageIQ::Providers::SomeManager::Job')
        inventory_g = inventory_group_stub.create!(:type => 'ManageIQ::Providers::SomeManager::InventoryGroup')

        migrate

        expect(mananger.reload.type).to eq('ManageIQ::Providers::SomeManager')
        expect(script.reload.type).to eq('ManageIQ::Providers::SomeManager::ConfigurationScript')
        expect(system.reload.type).to eq('ManageIQ::Providers::SomeManager::ConfiguredSystem')
        expect(job.reload.type).to eq('ManageIQ::Providers::SomeManager::Job')
        expect(inventory_g.reload.type).to eq('ManageIQ::Providers::SomeManager::InventoryGroup')
      end
    end
  end

  migration_context :down do
    it 'migrates Ansible Tower AutomationManager to ConfigurationManager type' do
      manager = ems_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager')
      script = configuration_script_stub.create!(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript'
      )
      system = configured_system_stub.create!(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem'
      )
      job = job_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Job')
      inventory_g = inventory_group_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::InventoryGroup')

      migrate

      expect(manager.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager')
      expect(script.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript')
      expect(system.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem')
      expect(job.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job')
      expect(inventory_g.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager::InventoryGroup')
    end
  end
end

require_migration

describe MigrateAnsibleTowerConfigurationManagerStiTypeToAutomationManager do
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }
  let(:configuration_script_stub) { migration_stub(:ConfigurationScript) }
  let(:configured_system_stub) { migration_stub(:ConfiguredSystem) }
  let(:job_stub) { migration_stub(:Job) }
  let(:inventory_group_stub) { migration_stub(:EmsFolder) }

  migration_context :up do
    context 'migrate_configuration_managers' do
      it 'migrates Ansible Tower ConfigurationManager to AutomationManager type' do
        configuration_manager = ems_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager')

        migrate

        expect(configuration_manager.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager')
      end

      it 'will not migrate other than Ansible Tower ConfigurationManager' do
        some_mananger = ems_stub.create!(:type => 'ManageIQ::Providers::SomeManager')

        migrate

        expect(some_mananger.reload.type).to eq('ManageIQ::Providers::SomeManager')
      end
    end

    context 'migrate_configuration_scripts' do
      it 'migrates Ansible Tower ConfigurationScript to be of AutomationManager type' do
        cs = configuration_script_stub.create!(
          :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript'
        )

        migrate

        expect(cs.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript')
      end

      it 'will not migrate ConfigurationScript of other than Ansible Tower ConfigurationManager' do
        cs = configuration_script_stub.create!(:type => 'ManageIQ::Providers::SomeManager::ConfigurationScript')

        migrate

        expect(cs.reload.type).to eq('ManageIQ::Providers::SomeManager::ConfigurationScript')
      end
    end

    context 'migrate_configured_systems' do
      it 'migrates Ansible Tower ConfiguredSystem to be of AutomationManager type' do
        cs = configured_system_stub.create!(
          :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem'
        )

        migrate

        expect(cs.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem')
      end

      it 'will not migrate ConfiguredSystem of other than Ansible Tower ConfigurationManager' do
        cs = configured_system_stub.create!(:type => 'ManageIQ::Providers::SomeManager::ConfiguredSystem')

        migrate

        expect(cs.reload.type).to eq('ManageIQ::Providers::SomeManager::ConfiguredSystem')
      end
    end

    context 'migrate_jobs' do
      it 'migrates Ansible Tower Job to be of AutomationManager type' do
        job = job_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job')

        migrate

        expect(job.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager::Job')
      end

      it 'will not migrate Job of other than Ansible Tower ConfigurationManager' do
        job = configured_system_stub.create!(:type => 'ManageIQ::Providers::SomeManager::Job')

        migrate

        expect(job.reload.type).to eq('ManageIQ::Providers::SomeManager::Job')
      end
    end

    context 'migrate_inventory_groups' do
      it 'migrates Ansible Tower InventoryGroup to be of AutomationManager type' do
        ig = inventory_group_stub.create!(
          :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::InventoryGroup'
        )

        migrate

        expect(ig.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager::InventoryGroup')
      end

      it 'will not migrate InventoryGroup of other than Ansible Tower ConfigurationManager' do
        ig = inventory_group_stub.create!(:type => 'ManageIQ::Providers::SomeManager::InventoryGroup')

        migrate

        expect(ig.reload.type).to eq('ManageIQ::Providers::SomeManager::InventoryGroup')
      end
    end
  end

  migration_context :down do
    it 'migrates Ansible Tower AutomationManager to ConfigurationManager type' do
      automation_manager = ems_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager')

      migrate

      expect(automation_manager.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager')
    end

    it 'migrates Ansible Tower ConfigurationScript to be of ConfigurationManager type' do
      cs = configuration_script_stub.create!(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript'
      )

      migrate

      expect(cs.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript')
    end

    it 'migrates Ansible Tower ConfiguredSystem to ConfigurationManager type' do
      cs = configured_system_stub.create!(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem'
      )

      migrate

      expect(cs.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem')
    end

    it 'migrates Ansible Tower Job to ConfigurationManager type' do
      job = job_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Job')

      migrate

      expect(job.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job')
    end

    it 'migrates Ansible Tower InventoryGroup to ConfigurationManager type' do
      ig = inventory_group_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::InventoryGroup')

      migrate

      expect(ig.reload.type).to eq('ManageIQ::Providers::AnsibleTower::ConfigurationManager::InventoryGroup')
    end
  end
end

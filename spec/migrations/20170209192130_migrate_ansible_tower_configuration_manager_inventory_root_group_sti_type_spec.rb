require_migration

describe MigrateAnsibleTowerConfigurationManagerInventoryRootGroupStiType do
  let(:inventory_root_group_stub) { migration_stub(:EmsFolder) }

  migration_context :up do
    it 'migrates Ansible Tower InventoryRootGroup to ManageIQ::Providers::AnsibleTower::AutomationManager::Inventory' do
      irg = inventory_root_group_stub.create!(
        :type => 'ManageIQ::Providers::ConfigurationManager::InventoryRootGroup'
      )

      migrate

      expect(irg.reload.type).to eq('ManageIQ::Providers::AnsibleTower::AutomationManager::Inventory')
    end

    it 'will not migrate InventoryRootGroup other than those of Ansible Tower ConfigurationManager' do
      irg = inventory_root_group_stub.create!(:type => 'ManageIQ::Providers::SomeManager::InventoryRootGroup')

      migrate

      expect(irg.reload.type).to eq('ManageIQ::Providers::SomeManager::InventoryRootGroup')
    end
  end

  migration_context :down do
    it 'migrates Ansible Tower InventoryRootGroup to ManageIQ::Providers::AnsibleTower::AutomationManager::Inventory' do
      irg = inventory_root_group_stub.create!(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Inventory')

      migrate

      expect(irg.reload.type).to eq('ManageIQ::Providers::ConfigurationManager::InventoryRootGroup')
    end
  end
end

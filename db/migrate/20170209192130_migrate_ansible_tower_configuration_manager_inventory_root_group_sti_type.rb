class MigrateAnsibleTowerConfigurationManagerInventoryRootGroupStiType < ActiveRecord::Migration[5.0]
  class EmsFolder < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time('Migrating STI type of ansible_tower inventory_root_groups to automation_manager inventorys') do
      EmsFolder.where(:type => 'ManageIQ::Providers::ConfigurationManager::InventoryRootGroup').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Inventory'
      )
    end
  end

  def down
    say_with_time('Migrating STI type of ansible_tower inventorys to configuration_manager inventory_root_groups') do
      EmsFolder.where(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Inventory').update_all(
        :type => 'ManageIQ::Providers::ConfigurationManager::InventoryRootGroup'
      )
    end
  end
end

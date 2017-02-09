class MigrateAnsibleTowerConfigurationManagerInventoryRootGroupStiType < ActiveRecord::Migration[5.0]
  class EmsFolder < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time('Migrating STI type of ansible_tower inventory_root_groups to be of automation_manager') do
      EmsFolder.where(:type => 'ManageIQ::Providers::ConfigurationManager::InventoryRootGroup').update_all(
        :type => 'ManageIQ::Providers::AutomationManager::InventoryRootGroup'
      )
    end
  end

  def down
    say_with_time('Migrating STI type of ansible_tower inventory_root_groups to be of configuration_manager') do
      EmsFolder.where(:type => 'ManageIQ::Providers::AutomationManager::InventoryRootGroup').update_all(
        :type => 'ManageIQ::Providers::ConfigurationManager::InventoryRootGroup'
      )
    end
  end
end

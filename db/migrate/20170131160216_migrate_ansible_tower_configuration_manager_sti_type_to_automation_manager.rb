class MigrateAnsibleTowerConfigurationManagerStiTypeToAutomationManager < ActiveRecord::Migration[5.0]
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class ConfigurationScript < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class ConfiguredSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class Job < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class EmsFolder < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time('Migrating STI type of ansible_tower configuration_managers to automation_managers') do
      ExtManagementSystem.where(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager'
      )
    end

    say_with_time('Migrating STI type of ansible_tower configuration_scripts to be of automation_manager') do
      ConfigurationScript.where(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript'
      )
    end

    say_with_time('Migrating STI type of ansible_tower configured_systems to be of automation_manager') do
      ConfiguredSystem.where(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem'
      )
    end

    say_with_time('Migrating STI type of ansible_tower jobs to be of automation_manager') do
      Job.where(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Job'
      )
    end

    say_with_time('Migrating STI type of ansible_tower inventory_groups to be of automation_manager') do
      EmsFolder.where(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::InventoryGroup').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::InventoryGroup'
      )
    end
  end

  def down
    say_with_time('Migrating STI type of ansible_tower automation_managers to configuration_managers') do
      ExtManagementSystem.where(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager'
      )
    end

    say_with_time('Migrating STI type of ansible_tower configuration_scripts to be of configuration_managers') do
      ConfigurationScript.where(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript'
      )
    end

    say_with_time('Migrating STI type of ansible_tower configured_systems to be of configuration_managers') do
      ConfiguredSystem.where(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem'
      )
    end

    say_with_time('Migrating STI type of ansible_tower jobs to be of configuration_managers') do
      Job.where(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Job').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job'
      )
    end

    say_with_time('Migrating STI type of ansible_tower inventory_groups to be of configuration_manager') do
      EmsFolder.where(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::InventoryGroup').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::InventoryGroup'
      )
    end
  end
end

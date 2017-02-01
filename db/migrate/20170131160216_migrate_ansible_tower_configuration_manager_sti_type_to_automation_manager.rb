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

  def up
    say_with_time("Migrating STI_type_of ansible_tower_configuration_managers to automation_managers") do
      ExtManagementSystem.where(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager'
      )
    end

    say_with_time("Migrating STI_type_of ansible_tower_configuration_scripts to_be_of automation_manager") do
      ConfigurationScript.where(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript'
      )
    end

    say_with_time("Migrating STI_type_of ansible_tower_configured_systems to_be_of automation_manager") do
      ConfiguredSystem.where(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem'
      )
    end
  end

  def down
    say_with_time("Migrating STI_type_of ansible_tower_automation_managers to configuration_managers") do
      ExtManagementSystem.where(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager'
      )
    end

    say_with_time("Migrating STI_type_of ansible_tower_configuration_scripts to_be_of configuration_managers") do
      ConfigurationScript.where(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript'
      )
    end

    say_with_time("Migrating STI_type_of ansible_tower_configured_systems to_be_of configuration_managers") do
      ConfiguredSystem.where(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem'
      )
    end
  end
end

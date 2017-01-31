class MigrateAnsibleTowerConfigurationManagerStiTypeToAutomationManager < ActiveRecord::Migration[5.0]
  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time("Migrating STI_type_of ansible_tower_configuration_managers to automation_managers") do
      ExtManagementSystem.where(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager'
      )
    end
  end

  def down
    say_with_time("Migrating STI_type_of ansible_tower_automation_managers to configuration_managers") do
      ExtManagementSystem.where(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager'
      )
    end
  end
end

class MigrateTowerJobStiTypeToAutomationManager < ActiveRecord::Migration[5.0]
  class OrchestrationStack < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time('Migrating STI type of ansible_tower jobs to be of automation_manager') do
      OrchestrationStack.where(:type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Job'
      )
    end
  end

  def down
    say_with_time('Migrating STI type of ansible_tower jobs to be of configuration_managers') do
      OrchestrationStack.where(:type => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Job').update_all(
        :type => 'ManageIQ::Providers::AnsibleTower::ConfigurationManager::Job'
      )
    end
  end
end

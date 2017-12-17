class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript <
  ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScript

  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScript
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::TowerApi

  FRIENDLY_NAME = "Ansible Automation Inside Job Template".freeze
end

class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource

  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScriptSource
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::TowerApi
end

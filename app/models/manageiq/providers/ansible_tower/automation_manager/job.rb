class ManageIQ::Providers::AnsibleTower::AutomationManager::Job <
  ManageIQ::Providers::ExternalAutomationManager::OrchestrationStack
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Job

  require_nested :Status
end

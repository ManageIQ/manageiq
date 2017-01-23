class ManageIQ::Providers::AnsibleTower::AutomationManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner
end

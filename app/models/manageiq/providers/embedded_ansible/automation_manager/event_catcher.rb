class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner
end

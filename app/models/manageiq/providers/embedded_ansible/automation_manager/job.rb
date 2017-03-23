class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job < ManageIQ::Providers::EmbeddedAutomationManager::OrchestrationStack
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Job

  require_nested :Status

  def retire_now(requester = nil)
    finish_retirement
    update_attributes(:retirement_requester => requester)
  end
end

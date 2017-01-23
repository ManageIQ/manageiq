class ManageIQ::Providers::EmbeddedAutomationManager < ManageIQ::Providers::AutomationManager
  include ManageIQ::Providers::AnsibleTower::AutomationManagerMixin
end

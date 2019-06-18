class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfiguredSystem < ManageIQ::Providers::EmbeddedAutomationManager::ConfiguredSystem
  include ProviderObjectMixin

  def ext_management_system
    manager
  end
end

class ManageIQ::Providers::ExternalAutomationManager < ManageIQ::Providers::AutomationManager
  require_nested :Authentication
  require_nested :ConfigurationScript
  require_nested :ConfigurationScriptPayload
  require_nested :ConfiguredSystem
  require_nested :OrchestrationStack
end

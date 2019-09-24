class ManageIQ::Providers::EmbeddedAutomationManager < ManageIQ::Providers::AutomationManager
  require_nested :Authentication
  require_nested :ConfigurationScript
  require_nested :ConfigurationScriptPayload
  require_nested :ConfigurationScriptSource
  require_nested :ConfiguredSystem
  require_nested :OrchestrationStack

  def self.supported_for_create?
    false
  end

  def supported_catalog_types
    %w(generic_ansible_playbook)
  end
end

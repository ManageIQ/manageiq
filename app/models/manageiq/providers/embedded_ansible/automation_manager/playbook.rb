class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook <
  ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptPayload

  has_many :jobs, :class_name => 'OrchestrationStack', :foreign_key => :configuration_script_base_id
end

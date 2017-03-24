class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Playbook <
  ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptPayload

  alias_attribute :project, :configuration_script_source
  has_many :jobs, :class_name => 'OrchestrationStack', :foreign_key => :configuration_script_base_id
end

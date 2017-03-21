class ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook <
  ManageIQ::Providers::ExternalAutomationManager::ConfigurationScriptPayload

  has_many :jobs, :class_name => 'OrchestrationStack', :foreign_key => :configuration_script_base_id
end

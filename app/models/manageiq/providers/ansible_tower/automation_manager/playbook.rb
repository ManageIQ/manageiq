class ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook < ConfigurationScriptPayload
  belongs_to :configuration_script_source, :class_name => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource"
end

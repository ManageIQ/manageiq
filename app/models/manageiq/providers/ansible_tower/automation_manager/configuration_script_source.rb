class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource < ConfigurationScriptSource
  has_many :playbooks
end

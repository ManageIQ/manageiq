class ManageIQ::Providers::AnsibleTower::AutomationManager::Project <
  ManageIQ::Providers::ExternalAutomationManager::ConfigurationScriptSource

  has_many :playbooks, :foreign_key => :configuration_scrip_source_id
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Project
end

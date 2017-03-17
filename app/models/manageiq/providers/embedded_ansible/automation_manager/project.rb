class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Project <
  ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource

  has_many :playbooks, :foreign_key => :configuration_scrip_source_id
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Project
end

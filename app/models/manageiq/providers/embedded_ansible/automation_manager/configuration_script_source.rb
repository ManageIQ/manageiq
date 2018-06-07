class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource < ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource

  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScriptSource
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::TowerApi

  FRIENDLY_NAME = "Ansible Automation Inside Project".freeze

  def self.display_name(number = 1)
    n_('Repository (Embedded Ansible)', 'Repositories (Embedded Ansible)', number)
  end
end

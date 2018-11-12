class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::GoogleCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::GoogleCredential

  def self.display_name(number = 1)
    n_('Credential (Google)', 'Credentials (Google)', number)
  end
end

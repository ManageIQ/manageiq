class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::RhvCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::RhvCredential

  def self.display_name(number = 1)
    n_('Credential (RHV)', 'Credentials (RHV)', number)
  end
end

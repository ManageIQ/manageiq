class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VaultCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::VaultCredential

  def self.display_name(number = 1)
    n_('Credential (Vault)', 'Credentials (Vault)', number)
  end
end

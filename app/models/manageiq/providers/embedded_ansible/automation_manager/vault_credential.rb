class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::VaultCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
  def self.display_name(number = 1)
    n_('Credential (Vault)', 'Credentials (Vault)', number)
  end
end

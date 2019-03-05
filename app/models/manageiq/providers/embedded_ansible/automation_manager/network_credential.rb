class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::NetworkCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
  def self.display_name(number = 1)
    n_('Credential (Network)', 'Credentials (Network)', number)
  end
end

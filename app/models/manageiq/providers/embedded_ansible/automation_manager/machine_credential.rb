class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
  def self.display_name(number = 1)
    n_('Credential (Machine)', 'Credentials (Machine)', number)
  end
end

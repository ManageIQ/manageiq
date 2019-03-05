class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AzureCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  def self.display_name(number = 1)
    n_('Credential (Microsoft Azure)', 'Credentials (Microsoft Azure)', number)
  end
end

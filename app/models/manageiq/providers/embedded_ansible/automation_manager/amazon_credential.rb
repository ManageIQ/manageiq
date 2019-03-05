class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::AmazonCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::CloudCredential
  def self.display_name(number = 1)
    n_('Credential (Amazon)', 'Credentials (Amazon)', number)
  end
end

class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ScmCredential < ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential
  def self.display_name(number = 1)
    n_('Credential (SCM)', 'Credentials (SCM)', number)
  end
end

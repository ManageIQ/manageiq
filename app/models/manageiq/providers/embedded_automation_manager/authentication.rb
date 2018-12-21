class ManageIQ::Providers::EmbeddedAutomationManager::Authentication <
  ManageIQ::Providers::AutomationManager::Authentication

  def self.display_name(number = 1)
    n_('Credential', 'Credentials', number)
  end
end

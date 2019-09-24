class ManageIQ::Providers::AutomationManager::Authentication < Authentication
  def self.display_name(number = 1)
    n_('Credential', 'Credentials', number)
  end
end

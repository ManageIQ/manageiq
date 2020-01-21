class ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource <
  ManageIQ::Providers::AutomationManager::ConfigurationScriptSource

  def self.display_name(number = 1)
    n_('Repository', 'Repositories', number)
  end
end

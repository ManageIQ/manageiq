class ManageIQ::Providers::ExternalAutomationManager::Authentication <
  ManageIQ::Providers::AutomationManager::Authentication
  def self.credential_type
    "external_credential_types"
  end
end

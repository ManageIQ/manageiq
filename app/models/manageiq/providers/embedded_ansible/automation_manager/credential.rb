class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential < ManageIQ::Providers::EmbeddedAutomationManager::Authentication
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Credential

  def self.provider_params(params)
    super.merge(:organization => ManageIQ::Providers::EmbeddedAnsible::AutomationManager.first.provider.default_organization)
  end
end

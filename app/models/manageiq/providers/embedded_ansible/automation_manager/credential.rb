class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential < ManageIQ::Providers::EmbeddedAutomationManager::Authentication
  # Authentication is associated with EMS through resource_id/resource_type
  # Alias is to make the AutomationManager code more uniformly as those
  # CUD operations in the TowerApi concern

  alias_attribute :manager_id, :resource_id
  alias_attribute :manager, :resource

  FRIENDLY_NAME = "Ansible Automation Inside Credential".freeze

  def self.provider_params(params)
    super.merge(:organization => ManageIQ::Providers::EmbeddedAnsible::AutomationManager.first.provider.default_organization)
  end

  def self.notify_on_provider_interaction?
    true
  end

  def native_ref
    Integer(manager_ref)
  end
end

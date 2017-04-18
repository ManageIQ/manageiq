class ManageIQ::Providers::AnsibleTower::AutomationManager::Credential < ManageIQ::Providers::ExternalAutomationManager::Authentication
  # Authentication is associated with EMS through resource_id/resource_type
  # Alias is to make the AutomationManager code more uniformly as those
  # CUD operations in the TowerApi concern

  alias_attribute :manager_id, :resource_id
  alias_attribute :manager, :resource

  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Credential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::TowerApi
end

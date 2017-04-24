class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential < ManageIQ::Providers::EmbeddedAutomationManager::Authentication
  # Authentication is associated with EMS through resource_id/resource_type
  # Alias is to make the AutomationManager code more uniformly as those
  # CUD operations in the TowerApi concern

  alias_attribute :manager_id, :resource_id
  alias_attribute :manager, :resource

  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Credential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::TowerApi

  def self.provider_params(params)
    # FIXME: workaround until https://github.com/ansible/ansible_tower_client_ruby/issues/68 is closed
    AnsibleTowerClient::Credential.new(nil, :organization => 1)
    super.merge(:organization => ManageIQ::Providers::EmbeddedAnsible::AutomationManager.first.provider.default_organization)
  end
end

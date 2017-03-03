class ManageIQ::Providers::AnsibleTower::AutomationManager::Credential < ManageIQ::Providers::ExternalAutomationManager::Authentication
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Credential

  COMMON_ATTRIBUTES = {}.freeze
  EXTRA_ATTRIBUTES = {}.freeze
  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze
end

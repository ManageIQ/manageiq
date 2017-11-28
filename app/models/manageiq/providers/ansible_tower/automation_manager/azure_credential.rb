# This corresponds to Ansible Tower's Azure Resource Manager (azure_rm) type credential
class ManageIQ::Providers::AnsibleTower::AutomationManager::AzureCredential < ManageIQ::Providers::AnsibleTower::AutomationManager::CloudCredential
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::AzureCredential
end

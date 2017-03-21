require 'support/ansible_shared/automation_manager/credential'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::Credential do
  it_behaves_like 'ansible credential'
end

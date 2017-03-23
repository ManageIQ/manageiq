require 'support/ansible_shared/automation_manager/credential'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::ScmCredential do
  it_behaves_like 'ansible credential', :provider_ansible_tower
end

require 'support/ansible_shared/automation_manager'

describe ManageIQ::Providers::AnsibleTower::AutomationManager do
  it_behaves_like 'ansible automation_manager'
end

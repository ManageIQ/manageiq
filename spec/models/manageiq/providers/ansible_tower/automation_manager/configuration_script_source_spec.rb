require 'support/ansible_shared/automation_manager/configuration_script_source'

describe ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource do
  it_behaves_like 'ansible configuration_script_source'
end

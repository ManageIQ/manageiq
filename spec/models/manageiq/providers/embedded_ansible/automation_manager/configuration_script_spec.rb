require 'support/ansible_shared/automation_manager/configuration_script'

describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript do
  it_behaves_like 'ansible configuration_script'
end

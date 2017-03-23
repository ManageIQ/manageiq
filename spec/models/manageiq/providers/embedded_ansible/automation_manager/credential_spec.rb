require 'support/ansible_shared/automation_manager/credential'

describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Credential do
  it_behaves_like 'ansible credential', :provider_embedded_ansible
end

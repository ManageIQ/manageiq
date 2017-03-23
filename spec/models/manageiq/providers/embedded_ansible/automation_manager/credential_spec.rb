require 'support/ansible_shared/automation_manager/credential'

describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ScmCredential do
  it_behaves_like 'ansible credential', :provider_embedded_ansible
end

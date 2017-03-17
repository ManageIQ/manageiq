require 'support/ansible_shared/automation_manager/project'

describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Project do
  it_behaves_like 'ansible project'

end

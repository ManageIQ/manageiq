require 'support/ansible_shared/automation_manager/refresher'

describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Refresher do
  it_behaves_like 'ansible refresher_v2',
                  :provider_embedded_ansible,
                  described_class.parent,
                  :embedded_ansible_automation,
                  ManageIQ::Providers::AnsibleTower::AutomationManager::Refresher.name.underscore
end

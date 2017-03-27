describe ManageIQ::Providers::AnsibleTower::AutomationManager::Refresher do
  it_behaves_like 'ansible refresher_v2',
                  :provider_ansible_tower,
                  described_class.parent,
                  :ansible_tower_automation,
                  described_class.name.underscore
end

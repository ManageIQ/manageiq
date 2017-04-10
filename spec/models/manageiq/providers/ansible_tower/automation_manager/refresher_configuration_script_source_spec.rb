describe ManageIQ::Providers::AnsibleTower::AutomationManager::Refresher do
  it_behaves_like 'refresh configuration_script_source',
                  :provider_ansible_tower,
                  described_class.parent,
                  :ansible_tower_automation,
                  described_class.name.underscore + '_configuration_script_source'
end

describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Refresher do
  before do
    EvmSpecHelper.assign_embedded_ansible_role
  end

  it_behaves_like 'ansible refresher',
                  :provider_embedded_ansible,
                  described_class.parent,
                  :embedded_ansible_automation,
                  ManageIQ::Providers::AnsibleTower::AutomationManager::Refresher.name.underscore
end

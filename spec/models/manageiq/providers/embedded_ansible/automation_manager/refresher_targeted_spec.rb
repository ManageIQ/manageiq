describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Refresher do
  before do
    EvmSpecHelper.assign_embedded_ansible_role
  end

  # TODO: uncomment later
  # it_behaves_like 'refresh targeted',
  #                 :provider_embedded_ansible,
  #                 described_class.parent,
  #                 :embedded_ansible,
  #                 ManageIQ::Providers::AnsibleTower::AutomationManager::Refresher.name.underscore + '_targeted'
end

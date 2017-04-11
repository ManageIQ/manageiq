describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Refresher do
  it_behaves_like 'refresh configuration_script_source',
                  :provider_embedded_ansible,
                  described_class.parent,
                  :embedded_ansible,
                  ManageIQ::Providers::AnsibleTower::AutomationManager::Refresher.name.underscore + '_targeted_configuration_script_source'
end

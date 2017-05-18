describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript do
  let(:provider_with_authentication)       { FactoryGirl.create(:provider_embedded_ansible, :with_authentication) }
  let(:manager_with_authentication)        { provider_with_authentication.managers.first }
  let(:manager_with_configuration_scripts) { FactoryGirl.create(:embedded_automation_manager_ansible, :provider, :configuration_script) }

  before do
    EvmSpecHelper.assign_embedded_ansible_role
  end

  it_behaves_like 'ansible configuration_script'
end

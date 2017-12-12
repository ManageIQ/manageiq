describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource do
  let(:manager) do
    FactoryGirl.create(:provider_embedded_ansible, :with_authentication, :default_organization => 1).managers.first
  end
  before do
    EvmSpecHelper.assign_embedded_ansible_role
  end

  it_behaves_like 'ansible configuration_script_source'
end

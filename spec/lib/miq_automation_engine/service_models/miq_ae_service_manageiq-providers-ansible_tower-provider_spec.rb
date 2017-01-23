describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_AnsibleTower_Provider do
  let(:provider) { FactoryGirl.create(:provider_ansible_tower) }
  let(:automation_manager) { FactoryGirl.create(:automation_manager_ansible_tower) }

  it "get the service model" do
    provider
    svc_model = described_class.find(provider.id)

    expect(svc_model.name).to eq(provider.name)
  end

  it "get automation manager" do
    provider.automation_manager = automation_manager
    svc_model = described_class.find(provider.id)

    expect(svc_model.automation_manager.name).to eq(automation_manager.name)
  end
end

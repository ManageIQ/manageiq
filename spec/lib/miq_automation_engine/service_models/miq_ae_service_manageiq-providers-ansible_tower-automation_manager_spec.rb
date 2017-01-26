describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_AnsibleTower_AutomationManager do
  let(:provider) { FactoryGirl.create(:provider_ansible_tower) }
  let(:automation_manager) { FactoryGirl.create(:automation_manager_ansible_tower, :provider => provider) }

  it "get the service model" do
    automation_manager
    svc = described_class.find(automation_manager.id)

    expect(svc.name).to eq(automation_manager.name)
  end
end

describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_AutomationManager_InventoryRootGroup do
  it "get the service model class" do
    expect { described_class }.not_to raise_error
  end

  it "#configuration_scripts" do
    expect(described_class.instance_methods).to include(:configuration_scripts)
  end
end

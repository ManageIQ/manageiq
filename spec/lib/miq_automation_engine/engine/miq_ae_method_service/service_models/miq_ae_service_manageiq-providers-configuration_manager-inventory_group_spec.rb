module MiqAeServiceManageIQProvidersConfigurationManagerInventoryGroupSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_ConfigurationManager_InventoryGroup do
    it "get the service model class" do
      expect { described_class }.not_to raise_error
    end

    it "#manager" do
      expect(described_class.instance_methods).to include(:manager)
    end
  end
end

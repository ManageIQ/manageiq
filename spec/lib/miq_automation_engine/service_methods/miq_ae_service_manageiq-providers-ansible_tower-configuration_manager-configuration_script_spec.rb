module MiqAeServiceManageIQProvidersAnsibleTowerConfigurationManagerConfigurationScriptSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_AnsibleTower_ConfigurationManager_ConfigurationScript do
    it "get the service model class" do
      expect { described_class }.not_to raise_error
    end

    it "#run" do
      expect(described_class.instance_methods).to include(:run)
    end
  end
end

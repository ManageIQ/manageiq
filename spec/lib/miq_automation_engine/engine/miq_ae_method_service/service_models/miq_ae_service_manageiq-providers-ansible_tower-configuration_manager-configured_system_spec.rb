module MiqAeServiceManageIQProvidersAnsibleTowerConfigurationManagerConfiguredSystemSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_AnsibleTower_ConfigurationManager_ConfiguredSystem do
    it "get the service model class" do
      expect { described_class }.not_to raise_error
    end
  end
end

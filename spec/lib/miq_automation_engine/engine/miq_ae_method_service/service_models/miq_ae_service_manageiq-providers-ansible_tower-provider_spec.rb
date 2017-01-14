module MiqAeServiceManageIQProvidersAnsibleTowerProviderSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_AnsibleTower_Provider do
    let(:provider) { FactoryGirl.create(:provider_ansible_tower) }
    let(:configuration_manager) { FactoryGirl.create(:configuration_manager_ansible_tower) }

    it "get the service model" do
      provider
      svc_model = described_class.find(provider.id)

      expect(svc_model.name).to eq(provider.name)
    end

    it "get configuration manager" do
      provider.configuration_manager = configuration_manager
      svc_model = described_class.find(provider.id)

      expect(svc_model.configuration_manager.name).to eq(configuration_manager.name)
    end
  end
end

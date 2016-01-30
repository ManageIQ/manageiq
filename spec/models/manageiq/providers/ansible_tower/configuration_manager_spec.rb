describe ManageIQ::Providers::AnsibleTower::ConfigurationManager do
  let(:provider)              { FactoryGirl.build(:provider_ansible_tower) }
  let(:configuration_manager) { FactoryGirl.build(:configuration_manager_ansible_tower, :provider => provider) }

  describe "#connect" do
    it "delegates to the provider" do
      expect(provider).to receive(:connect)
      configuration_manager.connect
    end
  end
end

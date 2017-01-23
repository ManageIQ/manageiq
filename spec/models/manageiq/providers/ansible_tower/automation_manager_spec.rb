describe ManageIQ::Providers::AnsibleTower::AutomationManager do
  let(:provider)           { FactoryGirl.build(:provider_ansible_tower) }
  let(:automation_manager) { FactoryGirl.build(:external_automation_manager_ansible_tower, :provider => provider) }

  describe "#connect" do
    it "delegates to the provider" do
      expect(provider).to receive(:connect)
      automation_manager.connect
    end
  end
end

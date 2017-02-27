describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager do
  let(:provider) { FactoryGirl.build(:provider) }
  let(:ansible_automation_manager) { FactoryGirl.build(:embedded_automation_manager_ansible, :provider => provider) }

  describe "#connect" do
    it "delegates to the provider" do
      expect(provider).to receive(:connect)
      ansible_automation_manager.connect
    end
  end
end

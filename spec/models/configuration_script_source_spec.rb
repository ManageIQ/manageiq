describe ConfigurationScriptSource do
  context '.class_for_manager' do
    it 'returns the correct configuration script source' do
      ems = FactoryGirl.create(:embedded_automation_manager_ansible)
      expect(described_class.class_for_manager(ems)).to eq(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource)
    end
  end
end

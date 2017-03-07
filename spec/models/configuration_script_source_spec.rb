describe ConfigurationScriptSource do
  context '.class_from_request_data' do
    it 'returns the correct configuration script source' do
      ems = FactoryGirl.create(:embedded_automation_manager_ansible, :name => 'foo')
      data = {
        'manager_resource' => ems.id
      }
      expect(described_class.class_from_request_data(data)).to eq(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource)
    end
  end
end

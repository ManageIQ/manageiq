describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager do
  context 'catalog types' do
    let(:ems) { FactoryBot.create(:embedded_automation_manager_ansible) }

    it "#supported_catalog_types" do
      expect(ems.supported_catalog_types).to eq(%w(generic_ansible_playbook))
    end
  end
end

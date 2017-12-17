describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager do
  it_behaves_like 'ansible automation_manager'

  context 'catalog types' do
    let(:ems) { FactoryGirl.create(:embedded_automation_manager) }

    it "#supported_catalog_types" do
      expect(ems.supported_catalog_types).to eq(%w(generic_ansible_playbook))
    end
  end
end

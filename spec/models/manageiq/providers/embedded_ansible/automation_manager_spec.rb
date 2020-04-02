RSpec.describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager do
  describe ".catalog_types" do
    it "includes generic_ansible_playbook" do
      expect(described_class.catalog_types).to include("generic_ansible_playbook")
    end
  end

  describe '#catalog_types' do
    let(:ems) { FactoryBot.create(:embedded_automation_manager_ansible) }

    it "includes generic_ansible_playbook" do
      expect(ems.catalog_types).to include("generic_ansible_playbook")
    end
  end
end

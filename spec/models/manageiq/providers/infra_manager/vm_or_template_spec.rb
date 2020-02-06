RSpec.describe ManageIQ::Providers::InfraManager::VmOrTemplate do
  describe "#all" do
    it "scopes" do
      vm = FactoryBot.create(:vm_vmware)
      t  = FactoryBot.create(:template_vmware)
      FactoryBot.create(:vm_openstack)
      FactoryBot.create(:template_openstack)

      expect(described_class.all).to match_array([vm, t])
    end
  end

  describe "#all_archived" do
    it "scopes" do
      ems = FactoryBot.create(:ems_vmware)
      vm = FactoryBot.create(:vm_vmware)
      t  = FactoryBot.create(:template_vmware)
      # non archived
      FactoryBot.create(:vm_vmware, :ext_management_system => ems)
      FactoryBot.create(:template_vmware, :ext_management_system => ems)
      # non infra
      FactoryBot.create(:vm_openstack)
      FactoryBot.create(:template_openstack)

      expect(described_class.archived).to match_array([vm, t])
    end
  end
end

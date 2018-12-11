describe ManageIQ::Providers::CloudManager::VmOrTemplate do
  describe "#all" do
    it "scopes" do
      vm = FactoryBot.create(:vm_openstack)
      t  = FactoryBot.create(:template_openstack)
      FactoryBot.create(:vm_vmware)
      FactoryBot.create(:template_vmware)

      expect(described_class.all).to match_array([vm, t])
    end
  end

  describe "#all_archived" do
    it "scopes" do
      ems = FactoryBot.create(:ems_openstack)
      vm = FactoryBot.create(:vm_openstack)
      t  = FactoryBot.create(:template_openstack)
      # non archived
      FactoryBot.create(:vm_openstack, :ext_management_system => ems)
      FactoryBot.create(:template_openstack, :ext_management_system => ems)
      # non cloud
      FactoryBot.create(:vm_vmware)
      FactoryBot.create(:template_vmware)

      expect(described_class.archived).to match_array([vm, t])
    end
  end
end

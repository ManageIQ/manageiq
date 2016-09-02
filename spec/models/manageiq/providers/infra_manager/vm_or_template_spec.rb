describe ManageIQ::Providers::InfraManager::VmOrTemplate do
  describe "#all" do
    it "scopes" do
      vm = FactoryGirl.create(:vm_vmware)
      t  = FactoryGirl.create(:template_vmware)
      FactoryGirl.create(:vm_openstack)
      FactoryGirl.create(:template_openstack)

      expect(described_class.all).to match_array([vm, t])
    end
  end

  describe "#all_archived" do
    it "scopes" do
      ems = FactoryGirl.create(:ems_vmware)
      vm = FactoryGirl.create(:vm_vmware)
      t  = FactoryGirl.create(:template_vmware)
      # non archived
      FactoryGirl.create(:vm_vmware, :ext_management_system => ems)
      FactoryGirl.create(:template_vmware, :ext_management_system => ems)
      # non infra
      FactoryGirl.create(:vm_openstack)
      FactoryGirl.create(:template_openstack)

      expect(described_class.all_archived).to match_array([vm, t])
    end
  end
end

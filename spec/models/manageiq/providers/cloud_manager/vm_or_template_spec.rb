describe ManageIQ::Providers::CloudManager::VmOrTemplate do
  describe "#all" do
    it "scopes" do
      vm = FactoryGirl.create(:vm_openstack)
      t  = FactoryGirl.create(:template_openstack)
      FactoryGirl.create(:vm_vmware)
      FactoryGirl.create(:template_vmware)

      expect(described_class.all).to match_array([vm, t])
    end
  end

  describe "#all_archived" do
    it "scopes" do
      ems = FactoryGirl.create(:ems_openstack)
      vm = FactoryGirl.create(:vm_openstack)
      t  = FactoryGirl.create(:template_openstack)
      # non archived
      FactoryGirl.create(:vm_openstack, :ext_management_system => ems)
      FactoryGirl.create(:template_openstack, :ext_management_system => ems)
      # non cloud
      FactoryGirl.create(:vm_vmware)
      FactoryGirl.create(:template_vmware)

      expect(described_class.all_archived).to match_array([vm, t])
    end
  end
end

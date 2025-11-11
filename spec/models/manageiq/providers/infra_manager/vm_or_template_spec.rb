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

  describe ".aar_scope_klass" do
    it "returns the class of the aar_scope" do
      expect(described_class.aar_scope_klass).to eq(::VmOrTemplate)
    end
  end

  describe ".orphaned" do
    it "delegates" do
      # orphaned adds a where clause. lets make sure it works well
      # VmOrTemplate is here to tack on a "type" - so we ignore that
      expect(described_class.orphaned.where_values_hash.except("type")).to eq(::VmOrTemplate.orphaned.where_values_hash.except("type"))
    end
  end

  describe ".archived" do
    it "delegates" do
      # VmOrTemplate is here to tack on a "type" - so we ignore that
      expect(described_class.archived.where_values_hash.except("type")).to eq(::VmOrTemplate.archived.where_values_hash.except("type"))
    end
  end
end

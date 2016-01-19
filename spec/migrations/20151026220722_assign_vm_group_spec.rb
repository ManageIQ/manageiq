require_migration

describe AssignVmGroup do
  let(:tenant_stub) { migration_stub(:Tenant) }
  let(:vmt_stub) { migration_stub(:VmOrTemplate) }
  let(:service_stub) { migration_stub(:Service) }

  migration_context :up do
    it "assigns vm groups" do
      tenant_stub.create!(:default_miq_group_id => 1)

      vm_without_group = vmt_stub.create!(:miq_group_id => nil)
      vm_with_group = vmt_stub.create!(:miq_group_id => 2)
      migrate

      expect(vm_without_group.reload.miq_group_id).to eq(1)
      expect(vm_with_group.reload.miq_group_id).to eq(2)
    end

    it "assigns service groups" do
      tenant_stub.create!(:default_miq_group_id => 1)

      service_without_group = service_stub.create!(:miq_group_id => nil)
      service_with_group = service_stub.create!(:miq_group_id => 2)
      migrate

      expect(service_without_group.reload.miq_group_id).to eq(1)
      expect(service_with_group.reload.miq_group_id).to eq(2)
    end
  end
end

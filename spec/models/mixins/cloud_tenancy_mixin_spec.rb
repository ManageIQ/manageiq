describe CloudTenancyMixin do
  let(:root_tenant) do
    Tenant.seed
  end

  let(:default_tenant) do
    root_tenant
    Tenant.default_tenant
  end

  describe "miq_group" do
    let(:user)         { FactoryGirl.create(:user, :userid => 'user', :miq_groups => [tenant_group]) }
    let(:tenant)       { FactoryGirl.build(:tenant, :parent => default_tenant) }
    let(:tenant_users) { FactoryGirl.create(:miq_user_role, :name => "tenant-users") }
    let(:tenant_group) { FactoryGirl.create(:miq_group, :miq_user_role => tenant_users, :tenant => tenant) }

    it "finds correct tenant id clause for regular tenants" do
      expect(VmOrTemplate.tenant_id_clause(user)).to eql ["(vms.template = true AND vms.tenant_id IN (?)) OR (vms.template = false AND vms.tenant_id IN (?))", [default_tenant.id, tenant.id], [tenant.id]]
    end

    it "finds correct tenant id clause for cloud tenants" do
      expect(CloudVolume.tenant_id_clause(user)).to eql ["(tenants.id IN (?) AND ext_management_systems.tenant_mapping_enabled IS TRUE) OR ext_management_systems.tenant_mapping_enabled IS FALSE", [tenant.id]]
    end
  end
end

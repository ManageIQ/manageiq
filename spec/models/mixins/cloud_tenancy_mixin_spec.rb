RSpec.describe CloudTenancyMixin do
  let(:root_tenant) do
    Tenant.seed
  end

  let(:default_tenant) do
    root_tenant
    Tenant.default_tenant
  end

  describe "miq_group" do
    let(:user)         { FactoryBot.create(:user, :userid => 'user', :miq_groups => [tenant_group]) }
    let(:tenant)       { FactoryBot.build(:tenant, :parent => default_tenant) }
    let(:tenant_users) { FactoryBot.create(:miq_user_role, :name => "tenant-users") }
    let(:tenant_group) { FactoryBot.create(:miq_group, :miq_user_role => tenant_users, :tenant => tenant) }

    it "finds correct tenant id clause for regular tenants" do
      expect(VmOrTemplate.tenant_id_clause(user)).to eql ["vms.template = true AND vms.tenant_id IN (?) OR vms.template = true AND vms.publicly_available = true AND vms.type IN (?) OR vms.template = false AND vms.tenant_id IN (?)", [default_tenant.id, tenant.id], ["ManageIQ::Providers::Openstack::CloudManager::Template"], [tenant.id]]

      query = VmOrTemplate.where(VmOrTemplate.tenant_id_clause(user))
      expect { query.load }.not_to raise_error
    end

    it "finds correct tenant id clause for cloud tenants" do
      expect(CloudVolume.tenant_id_clause(user)).to eql ["(tenants.id IN (?) AND ext_management_systems.tenant_mapping_enabled IS TRUE) OR ext_management_systems.tenant_mapping_enabled IS FALSE OR ext_management_systems.tenant_mapping_enabled IS NULL", [tenant.id]]

      query = CloudVolume.tenant_joins_clause(CloudVolume.all)
                         .where(CloudVolume.tenant_id_clause(user))
      expect { query.load }.not_to raise_error
    end

    # Overwrites CloudTenancyMixin.tenant_joins_clause
    it "finds correct tenant id clause for flavors" do
      expect(Flavor.tenant_id_clause(user)).to eql ["(tenants.id IN (?) AND ext_management_systems.tenant_mapping_enabled IS TRUE) OR ext_management_systems.tenant_mapping_enabled IS FALSE OR ext_management_systems.tenant_mapping_enabled IS NULL", [tenant.id]]

      query = Flavor.tenant_joins_clause(Flavor.all)
                    .where(Flavor.tenant_id_clause(user))
      expect { query.load }.not_to raise_error
    end

    # Overwrites CloudTenancyMixin.tenant_joins_clause
    it "finds correct tenant id clause for cloud tenants" do
      expect(CloudTenant.tenant_id_clause(user)).to eql ["(tenants.id IN (?) AND ext_management_systems.tenant_mapping_enabled IS TRUE) OR ext_management_systems.tenant_mapping_enabled IS FALSE OR ext_management_systems.tenant_mapping_enabled IS NULL", [tenant.id]]

      query = CloudTenant.tenant_joins_clause(CloudTenant.all)
                         .where(CloudTenant.tenant_id_clause(user))
      expect { query.load }.not_to raise_error
    end
  end
end

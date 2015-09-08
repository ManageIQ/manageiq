require "spec_helper"

module MiqAeServiceTenantSpec
  describe MiqAeMethodService::MiqAeServiceTenant do
    let(:settings) { {} }
    let(:tenant) { Tenant.create(:name => 'fred', :domain => 'a.b', :parent => root_tenant, :description => "Krueger") }

    let(:cpu_quota) { TenantQuota.create(:name => "cpu_allocated", :unit => "int", :value => 2, :tenant_id => tenant.id) }
    let(:storage_quota) { TenantQuota.create(:name => "storage_allocated", :unit => "GB", :value => 160, :tenant_id => tenant.id) }

    let(:root_tenant) do
      MiqRegion.seed
      Tenant.seed
      Tenant.root_tenant
    end

    let(:st_cpu_quota) { MiqAeMethodService::MiqAeServiceTenantQuota.find(cpu_quota.id) }
    let(:st_storage_quota) { MiqAeMethodService::MiqAeServiceTenantQuota.find(storage_quota.id) }
    let(:service_tenant) { MiqAeMethodService::MiqAeServiceTenant.find(tenant.id) }

    before do
      stub_server_configuration(settings)
    end

    it "#name" do
      expect(service_tenant.name).to eq('fred')
    end

    it "#domain" do
      expect(service_tenant.domain).to eq('a.b')
    end

    it "#description" do
      expect(service_tenant.description).to eq('Krueger')
    end

    it "#tenant_quotas" do
      ids = []
      ids << st_cpu_quota.id
      ids << st_storage_quota.id
      expect(service_tenant.tenant_quotas.collect(&:id)).to match_array(ids)
    end
  end
end

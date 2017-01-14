module MiqAeServiceTenantSpec
  describe MiqAeMethodService::MiqAeServiceTenant do
    let(:settings) { {} }
    let(:tenant) { FactoryGirl.create(:tenant, :name => 'fred', :domain => 'a.b', :description => "Krueger") }

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
      cpu_quota = FactoryGirl.create(:tenant_quota_cpu, :tenant_id => tenant.id)
      ids = [cpu_quota.id]
      expect(service_tenant.tenant_quotas.collect(&:id)).to match_array(ids)
    end
  end
end

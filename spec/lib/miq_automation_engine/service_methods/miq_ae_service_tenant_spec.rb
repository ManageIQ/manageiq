require "spec_helper"

module MiqAeServiceTenantSpec
  describe MiqAeMethodService::MiqAeServiceTenant do
    let(:settings) { {} }
    let(:tenant) { Tenant.create(:name => 'fred', :domain => 'a.b', :parent => def_tenant, :description => "Krueger") }

    let(:def_tenant) do
      Tenant.seed
      Tenant.default_tenant
    end

    let(:service_tenant) { MiqAeMethodService::MiqAeServiceTenant.find(tenant.id) }

    before do
      allow(VMDB::Config).to receive(:new).with("vmdb").and_return(double(:config => settings))
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
  end
end

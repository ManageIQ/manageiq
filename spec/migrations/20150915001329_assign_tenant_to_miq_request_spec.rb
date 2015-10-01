require "spec_helper"
require_migration

describe AssignTenantToMiqRequest do
  let(:tenant_stub)           { migration_stub(:Tenant) }
  let(:miq_group_stub)        { migration_stub(:MiqGroup) }
  let(:ems_stub)              { migration_stub(:ExtManagementSystem) }
  let(:miq_ae_namespace_stub) { migration_stub(:MiqAeNamespace) }
  let(:provider_stub)         { migration_stub(:Provider) }
  let(:vm_stub)               { migration_stub(:Vm) }
  let(:miq_request_stub)      { migration_stub(:MiqRequest) }
  let(:miq_request_task_stub) { migration_stub(:MiqRequestTask) }
  let(:service_stub)          { migration_stub(:Service) }
  let(:service_template_stub) { migration_stub(:ServiceTemplate) }
  let(:service_catalog_stub) { migration_stub(:ServiceTemplateCatalog) }

  let(:stubs) do
    [
      ems_stub, miq_ae_namespace_stub, miq_group_stub, provider_stub, vm_stub,
      miq_request_stub, miq_request_task_stub, service_stub, service_template_stub, service_catalog_stub
    ]
  end

  migration_context :up do
    describe "#root_tenant" do
      it "doesnt create tenant if no records exist" do
        migrate

        expect(tenant_stub.count).to eq(0)
      end

      it "creates tenant if needed" do
        miq_group_stub.create!
        migrate

        expect(tenant_stub.count).to eq(1)
        expect(tenant_stub.first).to be_use_config_for_attributes
      end

      it "doesnt creates additional root_tenant" do
        tenant_stub.create!
        miq_group_stub.create!

        migrate

        expect(tenant_stub.count).to eq(1)
        # make sure tenant was not modified
        expect(tenant_stub.first).not_to be_use_config_for_attributes
      end
    end

    it "updates existing records" do
      tenant_stub.root_tenant
      miq_group_stub.create!

      stubs.map(&:create!)

      migrate

      expect(tenant_stub.count).to eq(1)
      stubs.each do |stub|
        expect(stub.where(:tenant_id => nil).exists?).to be_false
      end
    end
  end
end

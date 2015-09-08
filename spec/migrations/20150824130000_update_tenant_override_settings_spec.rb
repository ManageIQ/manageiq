require "spec_helper"
require_migration

describe UpdateTenantOverrideSettings do
  let(:tenant_stub) { migration_stub(:Tenant) }

  migration_context :up do
    it "updates root_value" do
      root_tenant = tenant_stub.create!
      expect(root_tenant).not_to be_use_config_for_attributes

      migrate

      expect(root_tenant.reload).to be_use_config_for_attributes
    end

    it "leaves other tenants alone" do
      root_tenant = tenant_stub.create!
      child_tenant = root_tenant.children.create!
      expect(child_tenant).not_to be_use_config_for_attributes

      migrate

      expect(child_tenant).not_to be_use_config_for_attributes
    end
  end
end

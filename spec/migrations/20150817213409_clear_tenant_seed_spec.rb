require "spec_helper"
require_migration

describe ClearTenantSeed do
  migration_context :up do
    it "works with one tenants" do
      tenant = migration_stub(:Tenant).create(:name => 'My Company')
      migrate
      expect(tenant.reload.name).to be_nil
    end
  end
end

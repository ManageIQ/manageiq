require "spec_helper"
require_migration

describe TenantCfgNotNil do
  let(:tenant_stub) { migration_stub(:Tenant) }

  migration_context :up do
    it "doesnt change false" do
      tenant = tenant_stub.create(:use_config_for_attributes => false)
      migrate

      expect(tenant.reload.use_config_for_attributes).to be_false
    end

    it "doesnt change false" do
      tenant = tenant_stub.create(:use_config_for_attributes => true)
      migrate

      expect(tenant.reload.use_config_for_attributes).to be_true
    end

    it "doesnt changes nil" do
      tenant = tenant_stub.create(:use_config_for_attributes => nil)
      migrate

      expect(tenant.reload.use_config_for_attributes).to be_false
    end
  end
end

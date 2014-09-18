require "spec_helper"
require Rails.root.join("db/migrate/20140918140859_add_cloud_tenant_sti_column")

describe AddCloudTenantStiColumn do
  let(:cloud_tenant_stub) { migration_stub(:CloudTenant) }

  migration_context :up do
    it "Sets the default type for Cloud Tenant records to 'CloudTenantOpenstack'" do
      cloud_tenant_stub.create!(:name => "tenant 1")
      cloud_tenant_stub.create!(:name => "tenant 2")

      migrate

      cloud_tenant_stub.all.each { |tenant| tenant.type.should be == "CloudTenantOpenstack" }
    end
  end
end

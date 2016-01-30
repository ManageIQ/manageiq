require_migration

describe AddCloudTenantStiColumn do
  let(:cloud_tenant_stub) { migration_stub(:CloudTenant) }

  migration_context :up do
    it "Sets the default type for Cloud Tenant records to 'CloudTenantOpenstack'" do
      cloud_tenant_stub.create!(:name => "tenant 1")
      cloud_tenant_stub.create!(:name => "tenant 2")

      migrate

      cloud_tenant_stub.all.each { |tenant| expect(tenant.type).to eq("CloudTenantOpenstack") }
    end
  end
end

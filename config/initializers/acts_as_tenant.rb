begin
  ActsAsTenant.default_tenant = Tenant.default_tenant
rescue ActiveRecord::StatementInvalid
  # This fails during migration if the tenants table doesn't exist yet
  # Allow migration to proceed
end

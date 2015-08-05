begin
  ActsAsTenant.default_tenant = Tenant.default_tenant
rescue ActiveRecord::StatementInvalid, PG::ConnectionBad
  # This fails during migration if the tenants table doesn't exist yet
  # Allow migration to proceed
end

# fall back on just using config vmdb
ActsAsTenant.default_tenant ||= TenantDefault.new

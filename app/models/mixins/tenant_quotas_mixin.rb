module TenantQuotasMixin
  extend ActiveSupport::Concern

  def tenant_quotas_allowed?
    current_user = User.current_user
    return true if current_user.super_admin_user?
    return true unless current_user.miq_user_role.tenant_admin_user?

    current_tenant = current_user.current_tenant
    # don't allow tenant quotas for current tenant and for ancestors
    !(current_tenant == self || current_tenant.ancestor_ids.include?(id))
  end
end

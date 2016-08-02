module TenantIdentityMixin
  extend ActiveSupport::Concern

  def tenant_identity
    if ext_management_system
      ext_management_system.tenant_identity
    else
      User.super_admin.tap { |u| u.current_group = Tenant.root_tenant.default_miq_group }
    end
  end
end

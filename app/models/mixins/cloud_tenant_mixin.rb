module CloudTenantMixin
  extend ActiveSupport::Concern

  # TODO(lpichler) add synchronization
  def sync_cloud_tenants_with_tenants
    return unless supports_cloud_tenants?
  end
end

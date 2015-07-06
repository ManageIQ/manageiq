module CloudResourceQuotaHelper

  # lookup a cloud_resource_quota by name for the tenant and service
  def lookup_quota(cloud_tenant_id, service_name, quota_name)
    return unless cloud_tenant_id && service_name && quota_name
    service_name = service_name.to_s
    quota_name   = quota_name.to_s
    CloudResourceQuota.where(
        :cloud_tenant_id => cloud_tenant_id,
        :service_name    => service_name,
        :name            => quota_name).first
  end
end

module OpenstackHandle
  class NetworkDelegate < DelegateClass(Fog::Network::OpenStack)
    SERVICE_NAME = "Network"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end

    def security_groups_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :security_groups, :id)
    end

    def quotas_for_current_tenant
      @tenant_id ||= current_tenant['id']
      q = get_quota(@tenant_id).body['quota']
      # looks like the quota id and the tenant id are the same,
      # but set the tenant id anyway, just in case.
      q.merge!('tenant_id' => @tenant_id, 'service_name' => SERVICE_NAME)
    end

    def quotas_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :quotas_for_current_tenant, 'id', false)
    end

    def networks_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :networks, :id)
    end
  end
end

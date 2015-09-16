module OpenstackHandle
  class NetworkDelegate < DelegateClass(Fog::Network::OpenStack)
    SERVICE_NAME = "Network"

    attr_reader :name

    def initialize(dobj, os_handle, name)
      super(dobj)
      @os_handle = os_handle
      @name      = name
    end

    def security_groups_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :security_groups, :id)
    end

    def quotas_for_current_tenant
      if current_tenant.kind_of?(Hash)
        @tenant_id ||= current_tenant['id']
      else
        # Seems like keystone v3 has string in current_tenant
        @tenant_id ||= @os_handle.accessible_tenants.detect { |x| x.name == current_tenant }.try(:id)
      end

      return nil unless @tenant_id

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

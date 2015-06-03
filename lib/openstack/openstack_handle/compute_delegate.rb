module OpenstackHandle
  class ComputeDelegate < DelegateClass(Fog::Compute::OpenStack)
    SERVICE_NAME = "Compute"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end

    def servers_with_pagination_loop
      all_servers = servers.all
      last_server = all_servers.last

      # There is always default pagination in Nova, so we obtain all
      # the servers in loop, using last server of each page as marker.
      if last_server
        while (servers = self.servers.all('marker' => last_server.id)).count > 0
          last_server = servers.last
          all_servers.concat(servers)
        end
      end

      all_servers
    end

    def servers_for_accessible_tenants
      # We should be able to use the following call to retrieve the server list:
      #   servers.all(:detailed => true, :all_tenants => true)
      # However, doing so sometimes results in the server's public_ip_address attribute
      # not being set, when it should be.
      #
      # Iterating through the tenants always returns the proper value.
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :servers_with_pagination_loop, :id)
    end

    def security_groups_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :security_groups, :id)
    end

    def addresses_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :addresses, :id)
    end

    def quotas_for_current_tenant
      @tenant_id ||= current_tenant['id']
      q = get_quota(@tenant_id).body['quota_set']
      # looks like the quota id and the tenant id are the same,
      # but set the tenant id anyway, just in case.
      q.merge!('tenant_id' => @tenant_id, 'service_name' => SERVICE_NAME)
    end

    def quotas_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :quotas_for_current_tenant, 'id', false)
    end
  end
end

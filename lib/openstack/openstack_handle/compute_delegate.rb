module OpenstackHandle
  class ComputeDelegate < DelegateClass(Fog::Compute::OpenStack)
    SERVICE_NAME = "Compute"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end

    def servers_for_accessible_tenants
      # We should be able to use the following call to retrieve the server list:
      #   servers.all(:detailed => true, :all_tenants => true)
      # However, doing so sometimes results in the server's public_ip_address attribute
      # not being set, when it should be.
      #
      # Iterating through the tenants always returns the proper value.
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :servers, :id)
    end

    def security_groups_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :security_groups, :id)
    end

    def addresses_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :addresses, :id)
    end
  end
end

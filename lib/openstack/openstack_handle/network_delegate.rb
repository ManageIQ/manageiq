module OpenstackHandle
  class NetworkDelegate < DelegateClass(Fog::Network::OpenStack)
    SERVICE_NAME = "Network"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end

    def security_groups_for_accessable_tenants
      @os_handle.accessor_for_accessable_tenants(SERVICE_NAME, :security_groups, :id)
    end
  end
end

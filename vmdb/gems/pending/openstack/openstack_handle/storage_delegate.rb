module OpenstackHandle
  class StorageDelegate < DelegateClass(Fog::Storage::OpenStack)
    SERVICE_NAME = "Storage"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end

    def directories_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :directories, nil)
    end
  end
end

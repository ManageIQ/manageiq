module OpenstackHandle
  class StorageDelegate < DelegateClass(Fog::Storage::OpenStack)
    SERVICE_NAME = "Storage"

    attr_reader :name

    def initialize(dobj, os_handle, name)
      super(dobj)
      @os_handle = os_handle
      @name      = name
    end

    def directories_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(SERVICE_NAME, :directories, nil)
    end
  end
end

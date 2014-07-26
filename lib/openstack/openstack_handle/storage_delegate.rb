module OpenstackHandle
  class StorageDelegate < DelegateClass(Fog::Storage::OpenStack)
    SERVICE_NAME = "Storage"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end
  end
end

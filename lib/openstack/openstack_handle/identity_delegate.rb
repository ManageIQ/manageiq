module OpenstackHandle
  class IdentityDelegate < DelegateClass(Fog::Identity::OpenStack)
    SERVICE_NAME = "Identity"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end
  end
end

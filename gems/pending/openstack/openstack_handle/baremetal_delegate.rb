module OpenstackHandle
  class BaremetalDelegate < DelegateClass(Fog::Baremetal::OpenStack)
    SERVICE_NAME = "Baremetal"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end
  end
end

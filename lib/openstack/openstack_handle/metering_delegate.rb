module OpenstackHandle
  class MeteringDelegate < DelegateClass(Fog::Metering::OpenStack)
    SERVICE_NAME = "Metering"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end
  end
end

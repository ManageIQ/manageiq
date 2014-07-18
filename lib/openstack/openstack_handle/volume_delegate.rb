module OpenstackHandle
  class VolumeDelegate < DelegateClass(Fog::Volume::OpenStack)
    SERVICE_NAME = "Volume"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end
  end
end

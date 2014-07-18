module OpenstackHandle
  class ImageDelegate < DelegateClass(Fog::Image::OpenStack)
    SERVICE_NAME = "Image"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end

    def images_for_accessable_tenants
      @os_handle.accessor_for_accessable_tenants(SERVICE_NAME, :images, :id)
    end
  end
end

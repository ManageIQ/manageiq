module OpenstackHandle
  class ImageDelegate < DelegateClass(Fog::Image::OpenStack)
    SERVICE_NAME = "Image"

    def initialize(dobj, os_handle)
      super(dobj)
      @os_handle = os_handle
    end

    def images_with_pagination_loop
      all_images = images.details
      last_image = all_images.last

      # There is always default pagination in Glance, so we obtain all
      # the images in loop, using last image of each page as marker.
      if last_image
        while (images = self.images.details('marker', last_image.id)).count > 0
          last_image = images.last
          all_images.concat(images)
        end
      end

      all_images
    end

    def images_for_accessible_tenants
      @os_handle.accessor_for_accessible_tenants(
          SERVICE_NAME, :images_with_pagination_loop, :id)
    end
  end
end

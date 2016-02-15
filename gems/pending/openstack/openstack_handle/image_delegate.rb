module OpenstackHandle
  class ImageDelegate < DelegateClass(Fog::Image::OpenStack)
    include OpenstackHandle::HandledList
    include Vmdb::Logging

    SERVICE_NAME = "Image"

    attr_reader :name

    def initialize(dobj, os_handle, name)
      super(dobj)
      @delegated_object = dobj
      @os_handle        = os_handle
      @name             = name
    end

    def version
      case @delegated_object
      when Fog::Image::OpenStack::V1::Real
        :v1
      when Fog::Image::OpenStack::V2::Real
        :v2
      else
        raise "Non supported Glance version #{@delegated_object.class.name}"
      end
    end

    def images_with_pagination_loop
      all_images = images.all
      last_image = all_images.last

      # There is always default pagination in Glance, so we obtain all
      # the images in loop, using last image of each page as marker.
      if last_image
        while (images = self.images.all(:marker => last_image.id)).count > 0
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

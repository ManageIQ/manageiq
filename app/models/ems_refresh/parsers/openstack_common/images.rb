module EmsRefresh::Parsers::OpenstackCommon
  module Images
    
    def get_images
      images = @image_service.images_for_accessible_tenants
      process_collection(images, :vms) { |image| parse_image(image) }
    end

    def parse_image(image)
      uid = image.id

      parent_server_uid = parse_image_parent_id(image)

      new_result = {
        :type            => "TemplateOpenstack",
        :uid_ems         => uid,
        :ems_ref         => uid,
        :name            => image.name,
        :vendor          => "openstack",
        :raw_power_state => "never",
        :template        => true,
        :publicly_available => image.is_public
      }
      new_result[:parent_vm_uid] = parent_server_uid unless parent_server_uid.nil?
      new_result[:cloud_tenant]  = @data_index.fetch_path(:cloud_tenants, image.owner) if image.owner

      return uid, new_result
    end

    def parse_image_parent_id(image)
      image_parent = @image_service_name == :glance ? image.copy_from : image.server
      image_parent["id"] if image_parent
    end

  end
end  

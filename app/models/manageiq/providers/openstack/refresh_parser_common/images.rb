module ManageIQ::Providers::Openstack
  module RefreshParserCommon
    module Images
      def get_images
        images = @image_service.handled_list(:images)
        process_collection(images, :vms) { |image| parse_image(image) }
      end

      def parse_image(image)
        uid               = image.id
        parent_server_uid = parse_image_parent_id(image)

        new_result = {
          :type               => self.class.miq_template_type,
          :uid_ems            => uid,
          :ems_ref            => uid,
          :name               => image.name,
          :vendor             => "openstack",
          :raw_power_state    => "never",
          :template           => true,
          :publicly_available => public?(image),
          :hardware           => {
            :bitness             => architecture(image),
            :virtualization_type => image.properties.try(:[], 'hypervisor_type') || image.attributes['hypervisor_type'],
            :root_device_type    => image.disk_format,
            :size_on_disk        => image.size,
          }
        }
        new_result[:parent_vm_uid] = parent_server_uid unless parent_server_uid.nil?
        new_result[:cloud_tenant]  = @data_index.fetch_path(:cloud_tenants, image.owner) if image.owner

        return uid, new_result
      end

      def architecture(image)
        architecture = image.properties.try(:[], 'architecture') || image.attributes['architecture']
        return nil if architecture.blank?
        # Just simple name to bits, x86_64 will be the most used, we should probably support displaying of
        # architecture name
        architecture.include?("64") ? 64 : 32
      end

      def public?(image)
        # Glance v1
        return image.is_public if image.respond_to? :is_public
        # Glance v2
        image.visibility == 'private' if image.respond_to? :visibility
      end

      def parse_image_parent_id(image)
        if @image_service.name == :glance
          # What version of openstack is this glance v1 on some old openstack version?
          return image.copy_from["id"] if image.respond_to?(:copy_from) && image.copy_from
          # Glance V2
          return image.instance_uuid if image.respond_to? :instance_uuid
          # Glance V1
          image.properties.try(:[], 'instance_uuid')
        else
          # Probably nova images?
          image.server["id"] if image.server
        end
      end
    end
  end
end

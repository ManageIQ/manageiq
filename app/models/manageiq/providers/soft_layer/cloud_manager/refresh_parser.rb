module ManageIQ::Providers
  module SoftLayer
    class CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
      include ManageIQ::Providers::SoftLayer::RefreshHelperMethods
      include Vmdb::Logging

      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, options = {})
        @ems               = ems
        @compute           = ems.connect
        @options           = options
        @data              = {}
        @data_index        = {}
      end

      def ems_inv_to_hashes
        log_header = "Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

        _log.info("#{log_header}...")
        get_flavors
        get_availability_zones
        get_images
        get_instances
        get_tags
        _log.info("#{log_header}...Complete")

        link_volumes_to_base_snapshots

        @data
      end

      private

      def get_availability_zones
        # cannot get availability zones from provider; create a default one
        a_zones = [::Fog::Model.new(:name => @ems.name, :id => 'default')]
        process_collection(a_zones, :availability_zones) { |az| parse_az(az) }
      end

      def get_flavors
        flavors = @compute.flavors.all
        process_collection(flavors, :flavors) { |flavor| parse_flavor(flavor) }
      end

      def get_images
        images = @compute.images.all
        process_collection(images, :vms) { |image| parse_image(image) }
      end

      def get_instances
        instances = @compute.servers.all
        process_collection(instances, :vms) { |instance| parse_instance(instance) }
      end

      def get_tags
        tags = @compute.tags.all
        # process_collection(tags, :tags) { |tags| parse_tags(tags) }
      end

      def parse_az(az)
        id = az.id.downcase

        type = ManageIQ::Providers::SoftLayer::CloudManager::AvailabilityZone
        new_result = {
          :type    => type,
          :ems_ref => id,
          :name    => az.name,
        }
        return id, new_result
      end

      def parse_flavor(flavor)
        uid = flavor.id

        disk_size = flavor.disks.inject(0) do |sum, disk|
          sum + disk["diskImage"]["capacity"]
        end

        type = ManageIQ::Providers::SoftLayer::CloudManager::Flavor
        new_result = {
          :type           => type,
          :ems_ref        => flavor.id,
          :name           => flavor.id,
          :description    => flavor.name,
          :cpus           => flavor.cpu,
          :cpu_cores      => flavor.cpu,
          :memory         => flavor.ram,
          :root_disk_size => disk_size
        }

        return uid, new_result
      end

      def parse_image(image)
        # TODO: finish mapping for power state and os
        uid    = image.id
        type   = ManageIQ::Providers::SoftLayer::CloudManager::Template

        new_result = {
          :type               => type,
          :uid_ems            => image.id,
          :ems_ref            => image.id,
          :name               => image.name,
          :vendor             => "softlayer",
          :raw_power_state    => nil,
          :operating_system   => nil,
          :template           => true,
          :publicly_available => image.public?,
        }

        return uid, new_result
      end

      def parse_instance(instance)
        # TODO: mapping is not complete and valid
        uid = instance.id

        type = ManageIQ::Providers::SoftLayer::CloudManager::Vm
        new_result = {
          :type              => type,
          :uid_ems           => instance.id,
          :ems_ref           => instance.id,
          :name              => instance.name,
          :description       => instance.description,
          :vendor            => "softlayer",
          :raw_power_state   => instance.state,
          :flavor            => instance.flavor_id,
          :operating_system  => instance.os_code,
          :availability_zone => @data_index.fetch_path(:availability_zones, 'default'),
          :hardware          => {
            :cpu_sockets          => instance.cpu,
            :cpu_total_cores      => instance.cpu,
            :cpu_cores_per_socket => 1,
            :memory_mb            => instance.ram,
            :disks                => [], # TODO: populate
            :networks             => [], # TODO: populate
          }
        }

        return uid, new_result
      end
    end
  end
end

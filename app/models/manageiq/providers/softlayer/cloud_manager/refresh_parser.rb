require 'fog/softlayer'

module ManageIQ::Providers
  module SoftLayer
    class CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
      include Vmdb::Logging

      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, options = nil)
        @ems               = ems
        @connection        = ems.connect
        @options           = options || {}
        @data              = {}
        @data_index        = {}
      end

      def ems_inv_to_hashes
        log_header = "Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

        _log.info("#{log_header}...")
        get_flavors
        get_images
        get_instances
        get_tags
        _log.info("#{log_header}...Complete")

        link_volumes_to_base_snapshots

        @data
      end

      private

      def get_flavors
        flavors = @connection.flavors.all
        process_collection(flavors, :flavors) { |flavor| parse_flavor(flavor) }
      end

      def get_images
        images = @connection.images.all
        process_collection(images, :vms) { |image| parse_image(image) }
      end

      def get_instances
        instances = @connection.servers.all
        process_collection(instances, :vms) { |instance| parse_instance(instance) }
      end

      def get_tags
        tags = @connection.tags.all
        process_collection(tags, :tags) { |tags| parse_tags(tags) }
      end

      def process_collection(collection, key)
        @data[key] ||= []

        collection.each do |item|
          uid, new_result = yield(item)
          next if uid.nil?

          @data[key] << new_result
          @data_index.store_path(key, uid, new_result)
        end
      end

      def parse_flavor(flavor)
        uid = flavor.id

        type = ManageIQ::Providers::SoftLayer::CloudManager::Flavor
        new_result = {
          :type        => type,
          :ems_ref     => flavor.id,
          :name        => flavor.id,
          :description => flavor.name,
          :enabled     => true,
          :cpus        => flavor.cpu,
          :cpu_cores   => flavor.cpu,
          :memory      => flavor.ram,
        }

        return uid, new_result
      end

      def parse_image(image)
        uid    = image.id
        type   = ManageIQ::Providers::SoftLayer::CloudManager::Template

        new_result = {
          :type               => type,
          :uid_ems            => image.id,
          :ems_ref            => image.id,
          :name               => image.name,
          :vendor             => "softlayer",
          :raw_power_state    => "never",
          :operating_system   => image,
          :template           => true,
          :publicly_available => true,
        }

        return uid, new_result
      end

      def parse_instance(instance)
        uid    = instance.id
        name   = instance.name
        name ||= uid

        type = ManageIQ::Providers::SoftLayer::CloudManager::Vm
        new_result = {
          :type             => type,
          :uid_ems          => uid,
          :ems_ref          => uid,
          :name             => name,
          :description      => instance.description,
          :vendor           => "softlayer",
          :raw_power_state  => instance.state,
          :flavor           => instance.flavor_id,
          :parent_vm        => nil,
          :operating_system => instance.os_code,
          :key_pairs        => [],
          :cloud_network    => nil,
          :security_groups  => nil,
          :hardware         => {
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

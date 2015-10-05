module ManageIQ::Providers
  module Azure
    class CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
      include Vmdb::Logging

      VALID_LOCATION = /\w+/

      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, options = nil)
        @ems             = ems
        config           = ems.connect
        @subscription_id = config.subscription_id
        @vmm             = ::Azure::Armrest::VirtualMachineService.new(config)
        @asm             = ::Azure::Armrest::AvailabilitySetService.new(config)
        @options         = options || {}
        @data            = {}
        @data_index      = {}
      end

      def ems_inv_to_hashes
        log_header = "Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

        _log.info("#{log_header}...")
        get_series
        get_availability_sets
        get_instances
        clean_up_extra_flavor_keys
        _log.info("#{log_header}...Complete")

        @data
      end

      private

      def get_series
        series = []
        get_locations.each do |location|
          begin
            series << @vmm.series(location)
          rescue RestClient::BadGateway, RestClient::GatewayTimeout, RestClient::BadRequest
            next
          end
        end
        series = series.flatten
        series = series.uniq
        process_collection(series, :flavors) { |s| parse_series(s) }
      end

      def get_availability_sets
        a_zones = @asm.list
        process_collection(a_zones, :availability_zones) { |az| parse_az(az) }
      end

      def get_instances
        instances = @vmm.get_vms
        process_collection(instances, :vms) { |instance| parse_instance(instance) }
      end

      def process_collection(collection, key)
        @data[key] ||= []

        return if collection.nil?

        collection.each do |item|
          uid, new_result = yield(item)
          @data[key] << new_result
          @data_index.store_path(key, uid, new_result)
        end
      end

      def parse_series(s)
        name = uid = s['name']
        new_result = {
          :type           => "ManageIQ::Providers::Azure::CloudManager::Flavor",
          :ems_ref        => uid,
          :name           => name,
          :cpus           => s['numberOfCores'], # where are the virtual CPUs??
          :cpu_cores      => s['numberOfCores'],
          :memory         => s['memoryInMB'].to_f,

          # Extra keys
          :os_disk_size   => s['osDiskSizeInMB'] * 1024,
          :swap_disk_size => s['resourceDiskSizeInMB']

        }
        return uid, new_result
      end

      def parse_az(az)
        id = az["id"].downcase

        new_result = {
          :type    => "ManageIQ::Providers::Azure::CloudManager::AvailabilityZone",
          :ems_ref => id,
          :name    => az["name"],
        }
        return id, new_result
      end

      def parse_instance(instance)
        uid         = "#{@subscription_id}\\#{instance.fetch_path('resourceGroup')}\\#{instance.fetch_path('name')}"
        series_name = instance.fetch_path('properties', 'hardwareProfile', 'vmSize')
        az          = instance.fetch_path('properties', 'availabilitySet', 'id')
        series      = @data_index.fetch_path(:flavors, series_name)

        new_result = {
          :type             => 'ManageIQ::Providers::Azure::CloudManager::Vm',
          :uid_ems          => uid,
          :ems_ref          => uid,
          :name             => instance.fetch_path('name'),
          :vendor           => "Microsoft",
          :raw_power_state  => instance["powerStatus"],
          :operating_system => process_os(instance),
          :flavor           => series,
          :location         => uid,
          :hardware         => {
            :disks    => [], # Filled in later conditionally on flavor
            :networks => [], # Filled in later conditionally on what's available
          },
        }
        new_result[:availability_zone] = fetch_az(az) unless az.nil?

        populate_hardware_hash_with_disks(new_result[:hardware][:disks], instance)
        populate_hardware_hash_with_series_attributes(new_result[:hardware], instance, series)
        populate_hardware_hash_with_networks(new_result[:hardware][:networks], instance)

        return uid, new_result
      end

      def fetch_az(availability_zone)
        @data_index.fetch_path(:availability_zones, availability_zone.downcase)
      end

      def process_os(instance)
        {
          :product_name => guest_os(instance)
        }
      end

      def guest_os(instance)
        image_reference = instance.fetch_path('properties', 'storageProfile', 'imageReference')
        image_reference['offer'] + " " + image_reference['sku'].tr('-', ' ')
      end

      def populate_hardware_hash_with_disks(hardware_disks_array, instance)
        data_disks = instance.fetch_path('properties', 'storageProfile', 'dataDisks')
        data_disks.each do |disk|
          disk_size      = disk['diskSizeGB'] * 1.gigabyte
          disk_name      = disk['name']
          disk_location  = disk['vhd']['uri']

          add_instance_disk(hardware_disks_array, disk_size, disk_name, disk_location)
        end
      end

      def add_instance_disk(disks, size, name, location)
        super(disks, size, name, location, "azure")
      end

      def populate_hardware_hash_with_networks(hardware_networks_array, instance)
        nics = instance.fetch_path('properties', 'networkProfile', 'networkInterfaces')

        nics.each do |n|
          n['properties'].each do |n_prop|
            private_network = {
              :ipaddress => n_prop['properties']['privateIPAddress'],
              :hostname  => n_prop['name']
            }.delete_nils

            public_network = {
              :ipaddress => n_prop['properties']['publicIPAddress'],
              :hostname  => n_prop['name']
            }.delete_nils

            hardware_networks_array <<
              private_network.merge(:description => "private") unless private_network.blank?
            hardware_networks_array <<
              public_network.merge(:description => "public") unless public_network.blank?
          end
          hardware_networks_array.flatten!
        end
      end

      def populate_hardware_hash_with_series_attributes(hardware_hash, instance, series)
        return if series.nil?
        hardware_hash[:logical_cpus]  = series[:cpus]
        hardware_hash[:memory_cpu]    = series[:memory] # MB
        hardware_hash[:disk_capacity] = series[:os_disk_size] + series[:swap_disk_size]

        os_disk = instance.fetch_path('properties', 'storageProfile', 'osDisk')
        sz      = series[:os_disk_size]

        add_instance_disk(hardware_hash[:disks], sz, os_disk['name'], os_disk['vhd']) unless sz.zero?

        # No data availbale on swap disk? Called temp or resource disk.
      end

      def clean_up_extra_flavor_keys
        @data[:flavors].each do |f|
          f.delete(:os_disk_size)
          f.delete(:swap_disk_size)
        end
      end

      def get_locations
        @vmm.locations.collect do |location|
          location = location.delete(' ')
          location.match(VALID_LOCATION).to_s
        end
      end
    end
  end
end

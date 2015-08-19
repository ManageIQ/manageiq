module EmsRefresh
  module Parsers
    class Azure < ManageIQ::Providers::CloudManager::RefreshParser
      VALID_LOCATION = /\w+/i

      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, options = nil)
        @ems        = ems
        ems.connect
        @vmm        = ::Azure::Armrest::VirtualMachineManager.new
        @asm        = ::Azure::Armrest::AvailabilitySetManager.new
        @options    = options || {}
        @data       = {}
        @data_index = {}
      end

      def ems_inv_to_hashes
        log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

        $log.info("#{log_header}...")
        get_series
        get_availability_sets
        get_vms
        clean_up_extra_flavor_keys
        $log.info("#{log_header}...Complete")

        @data
      end

      private

      def get_series
        series = []
        get_locations.each do |location|
          begin
            series << @vmm.series(location)
          rescue RestClient::BadGateway
            next
          end
        end
        series = series.flatten!.uniq
        process_collection(series, :flavors) { |s| parse_series(s) }
      end

      def get_availability_sets
        a_zones = @asm.list
        process_collection(a_zones, :availability_zones) { |az| parse_az(az) }
      end

      def get_vms
        vms = @vmm.get_vms
        process_collection(vms, :vms) { |instance| parse_vm(instance) }
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
          :type           => "SeriesAzure",
          :ems_ref        => uid,
          :name           => name,
          :cpus           => s['numberOfCores'], # where are the virtual CPUs??
          :cpu_cores      => s['numberOfCores'],
          :memory         => s['memoryInMB'].to_f,

          # Extra keys
          :os_disk_size   => (s['osDiskSizeInMB'] * 1024),
          :swap_disk_size => s['resourceDiskSizeInMB']

        }
        return uid, new_result
      end

      def parse_az(az)
        name = az["name"]
        id   = az["id"].downcase

        new_result = {
          :type    => EmsAzure::AvailabilityZone.name,
          :ems_ref => id,
          :name    => name,
        }
        return id, new_result
      end

      def parse_vm(vm)
        uid               = vm.fetch_path('resourceGroup') + "\\" + vm.fetch_path('name')
        series_name       = vm.fetch_path('properties', 'hardwareProfile', 'vmSize')
        az                = vm.fetch_path('properties', 'availabilitySet', 'id')
        series            = @data_index.fetch_path(:flavors, series_name)

        new_result = {
          :type             => 'VmAzure',
          :uid_ems          => uid,
          :ems_ref          => uid,
          :name             => vm.fetch_path('name'),
          :vendor           => "Microsoft",
          :raw_power_state  => vm["powerStatus"],
          :operating_system => process_os(vm),
          :flavor           => series,
          :location         => uid,
          :hardware         => {
            :disks    => [], # Filled in later conditionally on flavor
            :networks => [], # Filled in later conditionally on what's available
            # Do we need to set the guest_os??
          },
        }
        new_result[:availability_zone] = fetch_az(az) unless az.nil?

        populate_hardware_hash_with_disks(new_result[:hardware][:disks], vm)
        populate_hardware_hash_with_series(new_result[:hardware], vm, series)
        populate_hardware_hash_with_networks(new_result[:hardware][:networks], vm)

        return uid, new_result
      end

      def fetch_az(availability_zone)
        @data_index.fetch_path(:availability_zones, availability_zone.downcase)
      end

      def process_os(vm)
        {
          :product_name => guest_os(vm)
        }
      end

      def guest_os(vm)
        image_reference = vm.fetch_path('properties', 'storageProfile', 'imageReference')
        image_reference['offer'] + " "  + image_reference['sku'].gsub('-', ' ')
      end

      def populate_hardware_hash_with_disks(hardware_disks_array, vm)
        data_disks = vm.fetch_path('properties', 'storageProfile', 'dataDisks')
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

      def populate_hardware_hash_with_networks(hardware_networks_array, vm)
        nics = vm.fetch_path('properties', 'networkProfile', 'networkInterfaces')

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
              public_network.merge(:description => "public")   unless public_network.blank?
          end
          hardware_networks_array.flatten!
        end
      end

      def populate_hardware_hash_with_series(hardware_hash, vm, series)
        return if series.nil?
        hardware_hash[:numvcpus]      = series[:cpus]
        hardware_hash[:logical_cpus]  = series[:cpus]
        hardware_hash[:memory_cpu]    = series[:memory] # MB
        hardware_hash[:disk_capacity] = series[:os_disk_size] + series[:swap_disk_size]

        os_disk = vm.fetch_path('properties', 'storageProfile', 'osDisk')
        sz      = series[:os_disk_size]

        add_instance_disk(hardware_hash[:disks], sz,  os_disk['name'], os_disk['vhd']) unless sz.zero?

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
          location.delete!(' ')
          location.match(VALID_LOCATION).to_s
        end
      end
    end
  end
end

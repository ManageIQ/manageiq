module ManageIQ::Providers
  module Azure
    class CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
      include Vmdb::Logging

      VALID_LOCATION = /\w+/
      TYPE_DEPLOYMENT = "microsoft.resources/deployments"

      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, options = nil)
        @ems               = ems
        config             = ems.connect
        @subscription_id   = config.subscription_id
        @vmm               = ::Azure::Armrest::VirtualMachineService.new(config)
        @asm               = ::Azure::Armrest::AvailabilitySetService.new(config)
        @tds               = ::Azure::Armrest::TemplateDeploymentService.new(config)
        @options           = options || {}
        @data              = {}
        @data_index        = {}
        @resource_to_stack = {}
      end

      def ems_inv_to_hashes
        log_header = "Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

        _log.info("#{log_header}...")
        get_series
        get_availability_sets
        get_stacks
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

      def get_stacks
        # deployments are realizations of a template in the Azure provider
        # they are parsed and converted to stacks in vmdb
        deployments = @tds.list
        process_collection(deployments, :orchestration_stacks) { |dp| parse_stack(dp) }
        update_nested_stack_relations
      end

      def get_stack_parameters(stack_id, parameters)
        process_collection(parameters, :orchestration_stack_parameters) do |param_key, param_val|
          parse_stack_parameter(param_key, param_val, stack_id)
        end
      end

      def get_stack_outputs(stack_id, outputs)
        process_collection(outputs, :orchestration_stack_outputs) do |output_key, output_val|
          parse_stack_output(output_key, output_val, stack_id)
        end
      end

      def get_stack_resources(name, group)
        resources = @tds.list_deployment_operations(name, group)
        resources.reject! { |r| r.fetch_path('properties', 'targetResource', 'id').nil? }

        process_collection(resources, :orchestration_stack_resources) do |resource|
          parse_stack_resource(resource, group)
        end
      end

      def get_stack_template(stack, content)
        process_collection([stack], :orchestration_templates) { |the_stack| parse_stack_template(the_stack, content) }
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
        uid = resource_uid(@subscription_id,
                           instance.fetch_path('resourceGroup'),
                           instance.fetch_path('type').downcase,
                           instance.fetch_path('name'))
        series_name = instance.fetch_path('properties', 'hardwareProfile', 'vmSize')
        az          = instance.fetch_path('properties', 'availabilitySet', 'id')
        series      = @data_index.fetch_path(:flavors, series_name)

        new_result = {
          :type                => 'ManageIQ::Providers::Azure::CloudManager::Vm',
          :uid_ems             => uid,
          :ems_ref             => uid,
          :name                => instance.fetch_path('name'),
          :vendor              => "Microsoft",
          :raw_power_state     => instance["powerStatus"],
          :operating_system    => process_os(instance),
          :flavor              => series,
          :location            => uid,
          :orchestration_stack => @data_index.fetch_path(:orchestration_stacks, @resource_to_stack[uid]),
          :hardware            => {
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
        image_reference['offer'] + " " + image_reference['sku'].gsub('-', ' ')
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

      def parse_stack(deployment)
        name = deployment.fetch_path('name')
        uid = resource_uid(@subscription_id,
                           deployment.fetch_path('resourceGroup'),
                           TYPE_DEPLOYMENT,
                           name)
        child_stacks, resources = stack_resources(deployment)
        new_result = {
          :type        => ManageIQ::Providers::Azure::CloudManager::OrchestrationStack.name,
          :ems_ref     => deployment.fetch_path('id'),
          :name        => name,
          :description => name,
          :status      => deployment.fetch_path('properties', 'provisioningState'),
          :children    => child_stacks,
          :resources   => resources,
          :outputs     => stack_outputs(deployment),
          :parameters  => stack_parameters(deployment),

          :orchestration_template => stack_template(deployment)
        }
        return uid, new_result
      end

      def stack_template(deployment)
        uri = deployment.fetch_path('properties', 'templateLink', 'uri')
        return unless uri

        content = download_template(uri)
        return unless content

        get_stack_template(deployment, content)
        @data_index.fetch_path(:orchestration_templates, deployment.fetch_path('id'))
      end

      def download_template(uri)
        require 'open-uri'
        open(uri) { |f| f.read }
      rescue => e
        _log.error("Failed to download Azure template #{uri}. Reason: #{e.inspect}")
        nil
      end

      def stack_parameters(deployment)
        raw_parameters = deployment.fetch_path('properties', 'parameters')
        return [] if raw_parameters.blank?

        stack_id = deployment.fetch_path('id')
        get_stack_parameters(stack_id, raw_parameters)
        raw_parameters.collect do |param_key, _val|
          @data_index.fetch_path(:orchestration_stack_parameters, resource_uid(stack_id, param_key))
        end
      end

      def stack_outputs(deployment)
        raw_outputs = deployment.fetch_path('properties', 'outputs')
        return [] if raw_outputs.blank?

        stack_id = deployment.fetch_path('id')
        get_stack_outputs(stack_id, raw_outputs)
        raw_outputs.collect do |output_key, _val|
          @data_index.fetch_path(:orchestration_stack_outputs, resource_uid(stack_id, output_key))
        end
      end

      def stack_resources(deployment)
        group = deployment.fetch_path('resourceGroup')
        name = deployment.fetch_path('name')
        stack_uid = resource_uid(@subscription_id, group, TYPE_DEPLOYMENT, name)

        raw_resources = get_stack_resources(name, group)

        child_stacks = []
        resources = raw_resources.collect do |resource|
          resource_type = resource.fetch_path('properties', 'targetResource', 'resourceType')
          resource_name = resource.fetch_path('properties', 'targetResource', 'resourceName')
          uid = resource_uid(@subscription_id, group, resource_type.downcase, resource_name)

          @resource_to_stack[uid] = stack_uid
          child_stacks << uid if resource_type.downcase == TYPE_DEPLOYMENT
          @data_index.fetch_path(:orchestration_stack_resources, uid)
        end

        return child_stacks, resources
      end

      def parse_stack_template(deployment, content)
        # Only need a temporary unique identifier for the template. Using the stack id is the cheapest way.
        uid = deployment.fetch_path('id')
        ver = deployment.fetch_path('properties', 'templateLink', 'contentVersion')

        new_result = {
          :type        => "OrchestrationTemplateAzure",
          :name        => deployment.fetch_path('name'),
          :description => "contentVersion: #{ver}",
          :content     => content
        }
        return uid, new_result
      end

      def parse_stack_parameter(param_key, param_obj, stack_id)
        uid = resource_uid(stack_id, param_key)
        new_result = {
          :ems_ref => uid,
          :name    => param_key,
          :value   => param_obj['value']
        }
        return uid, new_result
      end

      def parse_stack_output(output_key, output_obj, stack_id)
        uid = resource_uid(stack_id, output_key)
        new_result = {
          :ems_ref     => uid,
          :key         => output_key,
          :value       => output_obj['value'],
          :description => output_key
        }
        return uid, new_result
      end

      def parse_stack_resource(resource, group)
        status_message = resource.fetch_path('properties', 'statusMessage')
        new_result = {
          :ems_ref                => resource.fetch_path('properties', 'targetResource', 'id'),
          :name                   => resource.fetch_path('properties', 'targetResource', 'resourceName'),
          :logical_resource       => resource.fetch_path('properties', 'targetResource', 'resourceName'),
          :physical_resource      => resource.fetch_path('properties', 'trackingId'),
          :resource_category      => resource.fetch_path('properties', 'targetResource', 'resourceType'),
          :resource_status        => resource.fetch_path('properties', 'provisioningState'),
          :resource_status_reason => status_message || resource.fetch_path('properties', 'statusCode'),
          :last_updated           => resource.fetch_path('properties', 'timestamp')
        }
        uid = resource_uid(@subscription_id, group, new_result[:resource_category].downcase, new_result[:name])
        return uid, new_result
      end

      # Compose an id string combining some existing keys
      def resource_uid(*keys)
        keys.join('\\')
      end

      # Remap from children to parent
      def update_nested_stack_relations
        @data[:orchestration_stacks].each do |stack|
          stack[:children].each do |child_stack_id|
            child_stack = @data_index.fetch_path(:orchestration_stacks, child_stack_id)
            child_stack[:parent] = stack if child_stack
          end
          stack.delete(:children)
        end
      end
    end
  end
end

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
        @config            = ems.connect
        @subscription_id   = @config.subscription_id
        @vmm               = ::Azure::Armrest::VirtualMachineService.new(@config)
        @asm               = ::Azure::Armrest::AvailabilitySetService.new(@config)
        @tds               = ::Azure::Armrest::TemplateDeploymentService.new(@config)
        @vns               = ::Azure::Armrest::Network::VirtualNetworkService.new(@config)
        @ips               = ::Azure::Armrest::Network::IpAddressService.new(@config)
        @options           = options || {}
        @data              = {}
        @data_index        = {}
        @resource_to_stack = {}
      end

      def ems_inv_to_hashes
        log_header = "Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

        _log.info("#{log_header}...")
        get_series
        get_availability_zones
        get_stacks
        get_cloud_networks
        get_instances
        _log.info("#{log_header}...Complete")

        @data
      end

      private

      def get_series
        series = []
        get_locations.each do |location|
          begin
            series << @vmm.series(location)
          rescue ::Azure::Armrest::BadGatewayException,
                 ::Azure::Armrest::GatewayTimeoutException,
                 ::Azure::Armrest::BadRequestException
            next
          end
        end
        series = series.flatten
        series = series.uniq
        process_collection(series, :flavors) { |s| parse_series(s) }
      end

      def get_availability_zones
        # cannot get availability zones from provider; create a default one
        a_zones = [::Azure::Armrest::BaseModel.new(:name => @ems.name, :id => 'default')]
        process_collection(a_zones, :availability_zones) { |az| parse_az(az) }
      end

      def get_stacks
        # deployments are realizations of a template in the Azure provider
        # they are parsed and converted to stacks in vmdb
        deployments = @tds.list_all
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
        resources.reject! { |r| r.try(:properties).try(:target_resource).try(:id).nil? }

        process_collection(resources, :orchestration_stack_resources) do |resource|
          parse_stack_resource(resource, group)
        end
      end

      def get_stack_template(stack, content)
        process_collection([stack], :orchestration_templates) { |the_stack| parse_stack_template(the_stack, content) }
      end

      def get_cloud_networks
        cloud_networks = @vns.list_all
        process_collection(cloud_networks, :cloud_networks) { |cloud_network| parse_cloud_network(cloud_network) }
      end

      def get_cloud_subnets(cloud_network)
        subnets = cloud_network.properties.subnets
        process_collection(subnets, :cloud_subnets) { |subnet| parse_cloud_subnet(subnet) }
      end

      def get_instances
        instances = @vmm.list_all
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
        name = uid = s.name
        new_result = {
          :type           => "ManageIQ::Providers::Azure::CloudManager::Flavor",
          :ems_ref        => uid,
          :name           => name,
          :cpus           => s.number_of_cores, # where are the virtual CPUs??
          :cpu_cores      => s.number_of_cores,
          :memory         => s.memory_in_mb.to_f,
          :root_disk_size => s.os_disk_size_in_mb * 1024,
          :swap_disk_size => s.resource_disk_size_in_mb * 1024
        }
        return uid, new_result
      end

      def parse_az(az)
        id = az.id.downcase

        new_result = {
          :type    => "ManageIQ::Providers::Azure::CloudManager::AvailabilityZone",
          :ems_ref => id,
          :name    => az.name,
        }
        return id, new_result
      end

      def parse_cloud_network(cloud_network)
        cloud_subnets = get_cloud_subnets(cloud_network).collect do |raw_subnet|
          @data_index.fetch_path(:cloud_subnets, raw_subnet.id)
        end

        uid = resource_uid(@subscription_id,
                           cloud_network.resource_group.downcase,
                           cloud_network.type.downcase,
                           cloud_network.name)

        new_result = {
          :ems_ref             => cloud_network.id,
          :name                => cloud_network.name,
          :cidr                => cloud_network.properties.address_space.address_prefixes.join(", "),
          :enabled             => true,
          :cloud_subnets       => cloud_subnets,
          :orchestration_stack => @data_index.fetch_path(:orchestration_stacks, @resource_to_stack[uid]),
        }
        return uid, new_result
      end

      def parse_cloud_subnet(subnet)
        uid = subnet.id
        new_result = {
          :ems_ref => uid,
          :name    => subnet.name,
          :cidr    => subnet.properties.address_prefix,
        }
        return uid, new_result
      end

      def parse_instance(instance)
        uid = resource_uid(@subscription_id,
                           instance.resource_group.downcase,
                           instance.type.downcase,
                           instance.name)
        series_name = instance.properties.hardware_profile.vm_size
        series      = @data_index.fetch_path(:flavors, series_name)

        new_result = {
          :type                => 'ManageIQ::Providers::Azure::CloudManager::Vm',
          :uid_ems             => uid,
          :ems_ref             => uid,
          :name                => instance.name,
          :vendor              => "Microsoft",
          :raw_power_state     => power_status(instance),
          :operating_system    => process_os(instance),
          :flavor              => series,
          :location            => uid,
          :orchestration_stack => @data_index.fetch_path(:orchestration_stacks, @resource_to_stack[uid]),
          :availability_zone   => @data_index.fetch_path(:availability_zones, 'default'),
          :hardware            => {
            :disks    => [], # Filled in later conditionally on flavor
            :networks => [], # Filled in later conditionally on what's available
          },
        }
        populate_hardware_hash_with_disks(new_result[:hardware][:disks], instance)
        populate_hardware_hash_with_series_attributes(new_result[:hardware], instance, series)
        populate_hardware_hash_with_networks(new_result[:hardware][:networks], instance)

        return uid, new_result
      end

      def power_status(instance)
        view = @vmm.get_instance_view(instance.name, instance.resource_group)
        status = view.statuses.find { |s| s.code =~ %r{^PowerState/} }
        status.display_status if status
      end

      def process_os(instance)
        {
          :product_name => guest_os(instance)
        }
      end

      def guest_os(instance)
        image_reference = instance.properties.storage_profile.image_reference
        image_reference.offer + " " + image_reference.sku.tr('-', ' ')
      end

      def populate_hardware_hash_with_disks(hardware_disks_array, instance)
        data_disks = instance.properties.storage_profile.data_disks
        data_disks.each do |disk|
          disk_size      = disk.disk_size_gb * 1.gigabyte
          disk_name      = disk.name
          disk_location  = disk.vhd.uri

          add_instance_disk(hardware_disks_array, disk_size, disk_name, disk_location)
        end
      end

      def add_instance_disk(disks, size, name, location)
        super(disks, size, name, location, "azure")
      end

      def populate_hardware_hash_with_networks(networks_array, instance)
        instance.properties.network_profile.network_interfaces.each do |nic|
          pattern = %r{/subscriptions/(.+)/resourceGroups/([\w-]+)/.+/networkInterfaces/(.+)}i
          _m, sub, group, nic_name = nic.id.match(pattern).to_a

          cfg = @config.clone.tap { |c| c.subscription_id = sub }
          nic_profile = ::Azure::Armrest::Network::NetworkInterfaceService.new(cfg).get(nic_name, group)

          nic_profile.properties.ip_configurations.each do |ipconfig|
            hostname = ipconfig.name
            private_ip_addr = ipconfig.properties.try(:private_ip_address)
            if private_ip_addr
              networks_array << {:description => "private", :ipaddress => private_ip_addr, :hostname => hostname}
            end

            public_ip_obj = ipconfig.properties.try(:public_ip_address)
            next unless public_ip_obj

            name = File.basename(public_ip_obj.id)
            ip_profile = ::Azure::Armrest::Network::IpAddressService.new(cfg).get(name, group)
            public_ip_addr = ip_profile.properties.try(:ip_address)
            networks_array << {:description => "public", :ipaddress => public_ip_addr, :hostname => hostname}
          end
        end
      end

      def populate_hardware_hash_with_series_attributes(hardware_hash, instance, series)
        return if series.nil?
        hardware_hash[:cpu_total_cores] = series[:cpus]
        hardware_hash[:memory_mb]       = series[:memory]
        hardware_hash[:disk_capacity]   = series[:root_disk_size] + series[:swap_disk_size]

        os_disk = instance.properties.storage_profile.os_disk
        sz      = series[:root_disk_size]

        add_instance_disk(hardware_hash[:disks], sz, os_disk.name, os_disk.vhd) unless sz.zero?

        # No data availbale on swap disk? Called temp or resource disk.
      end

      def get_locations
        @vmm.locations.collect do |location|
          location = location.delete(' ')
          location.match(VALID_LOCATION).to_s
        end
      end

      def parse_stack(deployment)
        name = deployment.name
        uid = resource_uid(@subscription_id,
                           deployment.resource_group.downcase,
                           TYPE_DEPLOYMENT,
                           name)
        child_stacks, resources = stack_resources(deployment)
        new_result = {
          :type           => ManageIQ::Providers::Azure::CloudManager::OrchestrationStack.name,
          :ems_ref        => deployment.id,
          :name           => name,
          :description    => name,
          :status         => deployment.properties.provisioning_state,
          :children       => child_stacks,
          :resources      => resources,
          :outputs        => stack_outputs(deployment),
          :parameters     => stack_parameters(deployment),
          :resource_group => deployment.resource_group,

          :orchestration_template => stack_template(deployment)
        }
        return uid, new_result
      end

      def stack_template(deployment)
        uri = deployment.properties.try(:template_link).try(:uri)
        return unless uri

        content = download_template(uri)
        return unless content

        get_stack_template(deployment, content)
        @data_index.fetch_path(:orchestration_templates, deployment.id)
      end

      def download_template(uri)
        require 'open-uri'
        open(uri) { |f| f.read }
      rescue => e
        _log.error("Failed to download Azure template #{uri}. Reason: #{e.inspect}")
        nil
      end

      def stack_parameters(deployment)
        raw_parameters = deployment.properties.try(:parameters)
        return [] if raw_parameters.blank?

        stack_id = deployment.id
        get_stack_parameters(stack_id, raw_parameters)
        raw_parameters.collect do |param_key, _val|
          @data_index.fetch_path(:orchestration_stack_parameters, resource_uid(stack_id, param_key))
        end
      end

      def stack_outputs(deployment)
        raw_outputs = deployment.properties.try(:outputs)
        return [] if raw_outputs.blank?

        stack_id = deployment.id
        get_stack_outputs(stack_id, raw_outputs)
        raw_outputs.collect do |output_key, _val|
          @data_index.fetch_path(:orchestration_stack_outputs, resource_uid(stack_id, output_key))
        end
      end

      def stack_resources(deployment)
        group = deployment.resource_group
        name = deployment.name
        stack_uid = resource_uid(@subscription_id, group.downcase, TYPE_DEPLOYMENT, name)

        raw_resources = get_stack_resources(name, group)

        child_stacks = []
        resources = raw_resources.collect do |resource|
          resource_type = resource.properties.target_resource.resource_type
          resource_name = resource.properties.target_resource.resource_name
          uid = resource_uid(@subscription_id, group.downcase, resource_type.downcase, resource_name)
          @resource_to_stack[uid] = stack_uid
          child_stacks << uid if resource_type.downcase == TYPE_DEPLOYMENT
          @data_index.fetch_path(:orchestration_stack_resources, uid)
        end

        return child_stacks, resources
      end

      def parse_stack_template(deployment, content)
        # Only need a temporary unique identifier for the template. Using the stack id is the cheapest way.
        uid = deployment.id
        ver = deployment.properties.template_link.content_version

        new_result = {
          :type        => "OrchestrationTemplateAzure",
          :name        => deployment.name,
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
        status_message = resource.properties.try(:status_message)
        new_result = {
          :ems_ref                => resource.properties.target_resource.id,
          :name                   => resource.properties.target_resource.resource_name,
          :logical_resource       => resource.properties.target_resource.resource_name,
          :physical_resource      => resource.properties.tracking_id,
          :resource_category      => resource.properties.target_resource.resource_type,
          :resource_status        => resource.properties.provisioning_state,
          :resource_status_reason => status_message || resource.properties.status_code,
          :last_updated           => resource.properties.timestamp
        }
        uid = resource_uid(@subscription_id, group.downcase, new_result[:resource_category].downcase, new_result[:name])
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

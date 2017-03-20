module ManageIQ::Providers
  module Azure
    class CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
      include ManageIQ::Providers::Azure::RefreshHelperMethods
      include Vmdb::Logging

      TYPE_DEPLOYMENT = "microsoft.resources/deployments"

      def self.ems_inv_to_hashes(ems, options = nil)
        new(ems, options).ems_inv_to_hashes
      end

      def initialize(ems, options = nil)
        @ems    = ems
        @config = ems.connect
        @subscription_id = ems.subscription

        # TODO(lsmola) NetworkManager, remove network endpoints once this is entirely moved under NetworkManager
        @nis               = ::Azure::Armrest::Network::NetworkInterfaceService.new(@config)
        @ips               = ::Azure::Armrest::Network::IpAddressService.new(@config)
        @vmm               = ::Azure::Armrest::VirtualMachineService.new(@config)
        @asm               = ::Azure::Armrest::AvailabilitySetService.new(@config)
        @tds               = ::Azure::Armrest::TemplateDeploymentService.new(@config)
        @rgs               = ::Azure::Armrest::ResourceGroupService.new(@config)
        @sas               = ::Azure::Armrest::StorageAccountService.new(@config)
        @options           = options || {}
        @data              = {}
        @data_index        = {}
        @resource_to_stack = {}
      end

      def ems_inv_to_hashes
        log_header = "Collecting data for EMS : [#{@ems.name}] id: [#{@ems.id}]"

        _log.info("#{log_header}...")
        get_resource_groups
        get_series
        get_availability_zones
        get_stacks
        get_instances
        get_images
        _log.info("#{log_header}...Complete")

        @data
      end

      private

      def get_resource_groups
        process_collection(resource_groups, :resource_groups) do |resource_group|
          parse_resource_group(resource_group)
        end
      end

      def get_series
        series = []
        begin
          series = @vmm.series(@ems.provider_region)
        rescue ::Azure::Armrest::BadGatewayException, ::Azure::Armrest::GatewayTimeoutException,
               ::Azure::Armrest::BadRequestException => err
          _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
        end
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
        deployments = gather_data_for_this_region(@tds, 'list')
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
        # relying on deployment operations to collect resources; but each resource may appear multiple times
        # consolidate multiple appearances into only one
        resources.reject! do |resource|
          resource.properties.try(:target_resource).nil? || resource_already_collected?(resources, resource)
        end

        process_collection(resources, :orchestration_stack_resources) do |resource|
          parse_stack_resource(resource, group)
        end
      end

      def resource_already_collected?(all, resource)
        all.each do |old_resource|
          return false if old_resource.equal?(resource)
          old_id = old_resource.properties.target_resource.id
          search_id = resource.properties.target_resource.id
          if old_id == search_id
            transfer_selected_resource_properties(old_resource, resource)
            return true
          end
        end
      end

      def get_resource_status_message(resource)
        return nil unless resource.properties.respond_to?(:status_message)
        if resource.properties.status_message.respond_to?(:error)
          resource.properties.status_message.error.message
        else
          resource.properties.status_message.to_s
        end
      end

      # new_resource is to be excluded.
      # copy any failed state to the old resource; concatenate all status messages
      def transfer_selected_resource_properties(old_resource, new_resource)
        if new_resource.properties.provisioning_state != 'Succeeded'
          old_resource.properties.provisioning_state = new_resource.properties.provisioning_state
        end

        new_status_message = get_resource_status_message(new_resource)
        return unless new_status_message

        old_status_message = get_resource_status_message(old_resource)

        old_resource.properties['status_message'] = if old_status_message
                                                      "#{old_status_message}\n#{new_status_message}"
                                                    else
                                                      new_status_message
                                                    end
      end

      def get_stack_template(stack, content)
        process_collection([stack], :orchestration_templates) { |the_stack| parse_stack_template(the_stack, content) }
      end

      def get_instances
        instances = gather_data_for_this_region(@vmm)
        process_collection(instances, :vms) { |instance| parse_instance(instance) }
      end

      # The underlying method that gathers these images is a bit brittle.
      # Consequently, if it raises an error we just log it and move on so
      # that it doesn't affect the rest of inventory collection.
      #
      def get_images
        images = gather_data_for_this_region(@sas, 'list_all_private_images')
      rescue Azure::Armrest::ApiException => err
        _log.warn("Unable to collect Azure private images for: [#{@ems.name}] - [#{@ems.id}]: #{err.message}")
      else
        process_collection(images, :vms) { |image| parse_image(image) }
      end

      def parse_resource_group(resource_group)
        uid = resource_group.id
        new_result = {
          :type    => "ResourceGroup",
          :name    => resource_group.name,
          :ems_ref => uid,
        }
        return uid, new_result
      end

      def parse_series(s)
        name = uid = s.name.downcase
        new_result = {
          :type           => "ManageIQ::Providers::Azure::CloudManager::Flavor",
          :ems_ref        => uid,
          :name           => name,
          :cpus           => s.number_of_cores, # where are the virtual CPUs??
          :cpu_cores      => s.number_of_cores,
          :memory         => s.memory_in_mb.megabytes,
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

      def parse_instance(instance)
        uid = resource_uid(@subscription_id,
                           instance.resource_group.downcase,
                           instance.type.downcase,
                           instance.name)
        series_name = instance.properties.hardware_profile.vm_size.downcase
        series      = @data_index.fetch_path(:flavors, series_name)

        # TODO(lsmola) NetworkManager, storing IP addresses under hardware/network will go away, once all providers are
        # unified under the NetworkManager
        hardware_network_info = get_hardware_network_info(instance)

        new_result = {
          :type                => 'ManageIQ::Providers::Azure::CloudManager::Vm',
          :uid_ems             => uid,
          :ems_ref             => uid,
          :name                => instance.name,
          :vendor              => "azure",
          :raw_power_state     => power_status(instance),
          :operating_system    => process_os(instance),
          :flavor              => series,
          :location            => uid,
          :orchestration_stack => @data_index.fetch_path(:orchestration_stacks, @resource_to_stack[uid]),
          :availability_zone   => @data_index.fetch_path(:availability_zones, 'default'),
          :hardware            => {
            :disks    => [], # Filled in later conditionally on flavor
            :networks => hardware_network_info
          },
        }

        populate_hardware_hash_with_disks(new_result[:hardware][:disks], instance)
        populate_hardware_hash_with_series_attributes(new_result[:hardware], instance, series)

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

      # Find both OS and SKU if possible, otherwise just the OS type.
      def guest_os(instance)
        image_reference = instance.properties.storage_profile.try(:image_reference)
        if image_reference && image_reference.try(:offer)
          "#{image_reference.offer} #{image_reference.sku.tr('-', ' ')}"
        else
          instance.properties.storage_profile.os_disk.os_type
        end
      end

      def populate_hardware_hash_with_disks(hardware_disks_array, instance)
        data_disks = instance.properties.storage_profile.data_disks
        data_disks.each do |disk|
          disk_size      = disk.respond_to?(:disk_size_gb) ? disk.disk_size_gb * 1.gigabyte : 0
          disk_name      = disk.name
          disk_location  = disk.try(:vhd).try(:uri)

          add_instance_disk(hardware_disks_array, disk_size, disk_name, disk_location)
        end
      end

      def add_instance_disk(disks, size, name, location)
        super(disks, size, location, name, "azure")
      end

      # TODO(lsmola) NetworkManager, storing IP addresses under hardware/network will go away, once all providers are
      # unified under the NetworkManager
      def get_hardware_network_info(instance)
        networks_array = []

        get_vm_nics(instance).each do |nic_profile|
          nic_profile.properties.ip_configurations.each do |ipconfig|
            hostname = ipconfig.name
            private_ip_addr = ipconfig.properties.try(:private_ip_address)
            if private_ip_addr
              networks_array << {:description => "private", :ipaddress => private_ip_addr, :hostname => hostname}
            end

            public_ip_obj = ipconfig.properties.try(:public_ip_address)
            next unless public_ip_obj

            ip_profile = ip_addresses.find { |ip| ip.id == public_ip_obj.id }
            next unless ip_profile

            public_ip_addr = ip_profile.properties.try(:ip_address)
            networks_array << {:description => "public", :ipaddress => public_ip_addr, :hostname => hostname}
          end
        end

        networks_array
      end

      def populate_hardware_hash_with_series_attributes(hardware_hash, instance, series)
        return if series.nil?
        hardware_hash[:cpu_total_cores] = series[:cpus]
        hardware_hash[:memory_mb]       = series[:memory] / 1.megabyte
        hardware_hash[:disk_capacity]   = series[:root_disk_size] + series[:swap_disk_size]

        os_disk = instance.properties.storage_profile.os_disk
        sz      = series[:root_disk_size]
        vhd_loc = os_disk.try(:vhd).try(:uri)

        add_instance_disk(hardware_hash[:disks], sz, os_disk.name, vhd_loc) unless sz.zero?

        # No data availbale on swap disk? Called temp or resource disk.
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

        content = uri.nil? ? template_from_vmdb(deployment) : download_template(uri)
        return unless content

        get_stack_template(deployment, content)
        @data_index.fetch_path(:orchestration_templates, deployment.id)
      end

      def template_from_vmdb(deployment)
        find_by = {:name => deployment.name, :ems_ref => deployment.id, :ext_management_system => @ems}
        # TODO(lsmola) this is generating a huge amount of sql queries? Do we need it? Why do we touch DB here?
        # Can be at least written more effectively
        stack = ManageIQ::Providers::Azure::CloudManager::OrchestrationStack.find_by(find_by)
        stack.try(:orchestration_template).try(:content)
      end

      def download_template(uri)
        options = {
          :method      => 'get',
          :url         => uri,
          :proxy       => @config.proxy,
          :ssl_version => @config.ssl_version,
          :ssl_verify  => @config.ssl_verify
        }

        RestClient::Request.execute(options).body
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
        ver = deployment.properties.try(:template_link).try(:content_version)

        new_result = {
          :type        => "OrchestrationTemplateAzure",
          :name        => deployment.name,
          :description => "contentVersion: #{ver}",
          :content     => content,
          :orderable   => false
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
        status_message = get_resource_status_message(resource)
        status_code = resource.properties.try(:status_code)
        new_result = {
          :ems_ref                => resource.properties.target_resource.id,
          :name                   => resource.properties.target_resource.resource_name,
          :logical_resource       => resource.properties.target_resource.resource_name,
          :physical_resource      => resource.properties.tracking_id,
          :resource_category      => resource.properties.target_resource.resource_type,
          :resource_status        => resource.properties.provisioning_state,
          :resource_status_reason => status_message || status_code,
          :last_updated           => resource.properties.timestamp
        }
        uid = resource_uid(@subscription_id, group.downcase, new_result[:resource_category].downcase, new_result[:name])
        return uid, new_result
      end

      def parse_image(image)
        uid = image.uri
        new_result = {
          :type               => ManageIQ::Providers::Azure::CloudManager::Template.name,
          :uid_ems            => uid,
          :ems_ref            => uid,
          :name               => build_image_name(image),
          :description        => build_image_description(image),
          :location           => @ems.provider_region,
          :vendor             => "azure",
          :raw_power_state    => "never",
          :template           => true,
          :publicly_available => false,
          :hardware           => {
            :bitness  => 64,
            :guest_os => image.operating_system
          }
        }
        return uid, new_result
      end

      def build_image_name(image)
        # Strip the .vhd and Azure GUID extension, but retain path and base name.
        File.join(File.dirname(image.name), File.basename(File.basename(image.name, '.*'), '.*'))
      end

      def build_image_description(image)
        # Description is a concatenation of resource group and storage account
        "#{image.storage_account.resource_group}\\#{image.storage_account.name}"
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

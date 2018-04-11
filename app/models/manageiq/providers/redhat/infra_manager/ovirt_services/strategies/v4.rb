require 'ovirtsdk4'

module ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Strategies
  class V4
    include Vmdb::Logging

    attr_reader :ext_management_system

    VERSION_HASH = {:version => 4}.freeze

    def initialize(args)
      @ext_management_system = args[:ems]
    end

    def username_by_href(href)
      ext_management_system.with_provider_connection(VERSION_HASH) do |connection|
        user = connection.system_service.users_service.user_service(uuid_from_href(href)).get
        "#{user.name}@#{user.domain.name}"
      end
    end

    def cluster_name_href(href)
      ext_management_system.with_provider_connection(VERSION_HASH) do |connection|
        cluster_proxy_from_href(href, connection).name
      end
    end

    # Provisioning
    def get_host_proxy(host, connection)
      connection.system_service.hosts_service.host_service(host.uid_ems)
    end

    def clone_completed?(args)
      source = args[:source]
      phase_context = args[:phase_context]
      logger = args[:logger]

      source.with_provider_connection(VERSION_HASH) do |connection|
        vm = vm_service_by_href(phase_context[:new_vm_ems_ref], connection).get
        status = vm.status
        logger.info("The Vm being cloned is #{status}")
        status == OvirtSDK4::VmStatus::DOWN
      end
    end

    def destination_image_locked?(vm)
      vm.with_provider_object(VERSION_HASH) do |vm_proxy|
        vm_proxy.get.status == OvirtSDK4::VmStatus::IMAGE_LOCKED
      end
    end

    def populate_phase_context(phase_context, vm)
      phase_context[:new_vm_ems_ref] = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(vm.href)
    end

    def nics_for_vm(vm)
      vm.with_provider_connection(VERSION_HASH) do |connection|
        vm_proxy = connection.system_service.vms_service.vm_service(vm.uid_ems).get
        connection.follow_link(vm_proxy.nics)
      end
    end

    def cluster_find_network_by_name(href, network_name)
      ext_management_system.with_provider_connection(VERSION_HASH) do |connection|
        cluster_service = connection.system_service.clusters_service.cluster_service(uuid_from_href(href))
        networks = cluster_service.networks_service.list
        networks.detect { |n| n.name == network_name }
      end
    end

    def configure_vnic(args)
      vm = args[:vm]
      mac_addr = args[:mac_addr]
      interface = args[:interface]
      vnic = args[:vnic]

      vm.with_provider_connection(VERSION_HASH) do |connection|
        uuid = uuid_from_href(vm.ems_ref)
        profile_id = network_profile_id(connection, args[:network])
        nics_service = connection.system_service.vms_service.vm_service(uuid).nics_service
        options = {
          :name         => args[:nic_name] || vnic && vnic.name,
          :interface    => interface || vnic && vnic.interface,
          :mac          => mac_addr ? OvirtSDK4::Mac.new(:address => mac_addr) : vnic && vnic.mac,
          :vnic_profile => profile_id ? { :id => profile_id } : vnic && vnic.vnic_profile
        }.delete_blanks
        args[:logger].info("with options: <#{options.inspect}>")
        if vnic
          nics_service.nic_service(vnic.id).update(options)
        else
          nics_service.add(OvirtSDK4::Nic.new(options))
        end
      end
    end

    def powered_off_in_provider?(vm)
      vm.with_provider_object(VERSION_HASH) { |vm_service| vm_service.get.status } == OvirtSDK4::VmStatus::DOWN
    end

    def powered_on_in_provider?(vm)
      vm.with_provider_object(VERSION_HASH) { |vm_service| vm_service.get.status } == OvirtSDK4::VmStatus::UP
    end

    def vm_boot_from_cdrom(operation, name)
      operation.destination.with_provider_object(VERSION_HASH) do |vm_service|
        vm_service.start(
          :vm => {
            :os     => {
              :boot => {
                :devices => [OvirtSDK4::BootDevice::CDROM]
              }
            },
            :cdroms => [
              {
                :file => {
                  :id => name
                }
              }
            ]
          }
        )
      end
    rescue OvirtSDK4::Error
      raise ManageIQ::Providers::Redhat::InfraManager::OvirtServices::VmNotReadyToBoot
    end

    def detach_floppy(operation)
      operation.destination.with_provider_object(VERSION_HASH) do |vm_service|
        vm_service.update(:payloads => [])
      end
    end

    def vm_boot_from_network(operation)
      operation.destination.with_provider_object(VERSION_HASH) do |vm_service|
        vm_service.start(
          :vm => {
            :os => {
              :boot => {
                :devices => [
                  OvirtSDK4::BootDevice::NETWORK
                ]
              }
            }
          }
        )
      end
    rescue OvirtSDK4::Error
      raise ManageIQ::Providers::Redhat::InfraManager::OvirtServices::VmNotReadyToBoot
    end

    def get_template_proxy(template, connection)
      TemplateProxyDecorator.new(
        connection.system_service.templates_service.template_service(template.uid_ems),
        connection,
        self
      )
    end

    def get_vm_proxy(vm, connection)
      VmProxyDecorator.new(connection.system_service.vms_service.vm_service(vm.uid_ems), self)
    end

    def collect_disks_by_hrefs(disks)
      vm_disks = []
      ext_management_system.with_provider_connection(VERSION_HASH) do |connection|
        disks.each do |disk|
          parts = URI(disk).path.split('/')
          begin
            vm_disks << connection.system_service.storage_domains_service.storage_domain_service(parts[2]).disks_service.disk_service(parts[4]).get
          rescue OvirtSDK4::Error
            nil
          end
        end
      end
      vm_disks
    end

    def shutdown_guest(operation)
      operation.with_provider_object(VERSION_HASH, &:shutdown)
    rescue OvirtSDK4::Error
    end

    def reboot_guest(operation)
      operation.with_provider_object(VERSION_HASH, &:reboot)
    rescue OvirtSDK4::Error
    end

    def start_clone(source, clone_options, phase_context)
      source.with_provider_object(VERSION_HASH) do |rhevm_template|
        vm = rhevm_template.create_vm(clone_options)
        populate_phase_context(phase_context, vm)
      end
    end

    def vm_start(vm, cloud_init)
      opts = {}
      vm.with_provider_object(VERSION_HASH) do |rhevm_vm|
        opts = {:use_cloud_init => cloud_init} if cloud_init
        rhevm_vm.start(opts)
      end
    rescue OvirtSDK4::Error
    end

    def vm_stop(vm)
      vm.with_provider_object(VERSION_HASH, &:stop)
    rescue OvirtSDK4::Error
    end

    def vm_suspend(vm)
      vm.with_provider_object(VERSION_HASH, &:suspend)
    end

    def vm_reconfigure(vm, options = {})
      log_header = "EMS: [#{ext_management_system.name}] #{vm.class.name}: id [#{vm.id}], name [#{vm.name}], ems_ref [#{vm.ems_ref}]"
      spec = options[:spec]

      _log.info("#{log_header} Started...")

      vm.with_provider_object(VERSION_HASH) do |vm_service|
        # Retrieve the current representation of the virtual machine:
        # TODO: no need to retreive vm here, only if memory is updated
        vm = vm_service.get

        # Update the memory:
        memory = spec['memoryMB']
        update_vm_memory(vm, vm_service, memory.megabytes) if memory

        # Update the CPU:
        cpu_total = spec['numCPUs']
        cpu_cores = spec['numCoresPerSocket']
        cpu_sockets = cpu_total / (cpu_cores || vm.cpu.topology.cores) if cpu_total
        if cpu_cores || cpu_sockets
          vm_service.update(
            OvirtSDK4::Vm.new(
              :cpu => {
                :topology => {
                  :cores   => cpu_cores,
                  :sockets => cpu_sockets
                }
              }
            )
          )
        end

        # Remove disks:
        removed_disk_specs = spec['disksRemove']
        remove_vm_disks(vm_service, removed_disk_specs) if removed_disk_specs

        # Add disks:
        added_disk_specs = spec['disksAdd']
        add_vm_disks(vm_service, added_disk_specs) if added_disk_specs
      end

      _log.info("#{log_header} Completed.")
    end

    def advertised_images
      ext_management_system.with_provider_connection(VERSION_HASH) do |ems_service|
        query = { :search => "status=#{OvirtSDK4::DataCenterStatus::UP}" }
        data_centers = ems_service.system_service.data_centers_service.list(:query => query)
        iso_sd = nil
        data_centers.each do |dc|
          iso_sd = ems_service.follow_link(dc.storage_domains).detect do |sd|
            sd.type == OvirtSDK4::StorageDomainType::ISO && sd.status == OvirtSDK4::StorageDomainStatus::ACTIVE
          end
          break iso_sd if iso_sd
        end
        return [] unless iso_sd
        sd_service = ems_service.system_service.storage_domains_service.storage_domain_service(iso_sd.id)
        iso_images = sd_service.files_service.list
        iso_images.collect(&:name)
      end
    rescue OvirtSDK4::Error => err
      name = ext_management_system.try(:name)
      _log.error("Error Getting ISO Images on ISO Datastore on Management System <#{name}>: #{err.class.name}: #{err}")
      raise ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Error, err
    end

    class VmProxyDecorator < SimpleDelegator
      attr_reader :service
      def initialize(vm, service)
        @obj = vm
        @service = service
        super(vm)
      end

      def update_memory_reserve!(memory_reserve_size)
        vm = get
        vm.memory_policy.guaranteed = memory_reserve_size
        update(vm)
      end

      def update_description!(description)
        vm = get
        vm.description = description
        update(vm)
      end

      def update_memory!(memory)
        vm = get
        vm.memory = memory
        update(vm)
      end

      def update_host_affinity!(dest_host_ems_ref)
        vm = get
        vm.placement_policy.hosts = [OvirtSDK4::Host.new(:id => service.uuid_from_href(dest_host_ems_ref))]
        update(vm)
      end

      def update_cpu_topology!(cpu_hash)
        vm = get
        vm.cpu.topology = OvirtSDK4::CpuTopology.new(cpu_hash)
        update(vm)
      end

      def destroy
        remove
      end
    end

    class TemplateProxyDecorator < SimpleDelegator
      attr_reader :connection, :ovirt_services
      def initialize(template_service, connection, ovirt_services)
        @obj = template_service
        @connection = connection
        @ovirt_services = ovirt_services
        super(template_service)
      end

      def create_vm(options)
        vms_service = connection.system_service.vms_service
        cluster = ovirt_services.cluster_from_href(options[:cluster], connection)
        template = get
        vm = build_vm_from_hash(:name     => options[:name],
                                :template => template,
                                :cluster  => cluster)
        vms_service.add(vm)
      end

      def build_vm_from_hash(args)
        OvirtSDK4::Vm.new(:name     => args[:name],
                          :template => args[:template],
                          :cluster  => args[:cluster])
      end
    end

    def cluster_from_href(href, connection)
      connection.system_service.clusters_service.cluster_service(uuid_from_href(href)).get
    end

    def uuid_from_href(ems_ref)
      URI(ems_ref).path.split('/').last
    end

    def find_mac_address_on_network(nics, network, log)
      ext_management_system.with_provider_connection(VERSION_HASH) do |connection|
        nic = nics.detect do |n|
          connection.follow_link(n.vnic_profile).network.id == network.id
        end
        log.warn "Cannot find NIC with network id=#{network.id}" if nic.nil?
        nic && nic.mac && nic.mac.address
      end
    end

    def event_fetcher
      ManageIQ::Providers::Redhat::InfraManager::EventFetcher.new(ext_management_system)
    end

    private

    #
    # Hot plug of virtual memory has to be done in quanta of this size. Actually this is configurable in the
    # engine, using the `HotPlugMemoryMultiplicationSizeMb` configuration parameter, but it is very unlikely
    # that it will change.
    #
    HOT_PLUG_DIMM_SIZE = 256.megabyte.freeze

    def cluster_proxy_from_href(href, connection)
      connection.system_service.clusters_service.cluster_service(uuid_from_href(href)).get
    end

    def vm_service_by_href(href, connection)
      vm_uuid = uuid_from_href(href)
      connection.system_service.vms_service.vm_service(vm_uuid)
    end

    def network_profile_id(connection, network_id)
      profiles_service = connection.system_service.vnic_profiles_service
      profile = profiles_service.list.detect { |pr| pr.network.id == network_id }
      profile && profile.id
    end

    #
    # Updates the amount memory of a virtual machine.
    #
    # @param vm [OvirtSDK4::Vm] The current representation of the virtual machine.
    # @param vm_service [OvirtSDK4::VmService] The service that manages the virtual machine.
    # @param memory [Integer] The new amount of memory requested by the user.
    #
    def update_vm_memory(vm, vm_service, memory)
      # Calculate the adjusted virtual and guaranteed memory:
      virtual = calculate_adjusted_virtual_memory(vm, memory)
      guaranteed = calculate_adjusted_guaranteed_memory(vm, memory)

      # The required memory cannot exceed the max configured memory of the VM. Therefore, we'll increase the max
      # memory up to 1TB or to the required limit, to allow a successful update for the VM.
      # Once 'max' memory attribute will be introduced, this code should be replaced with the specified max memory.
      supports_max = ext_management_system.version_higher_than?('4.1')
      max = calculate_max_memory(vm, memory) if supports_max

      # If the virtual machine is running we need to update first the configuration that will be used during the
      # next run, as the guaranteed memory can't be changed for the running virtual machine.
      if vm.status == OvirtSDK4::VmStatus::UP
        vm_service.update(
          OvirtSDK4::Vm.new(
            :memory        => virtual,
            :memory_policy => {
              :guaranteed => guaranteed,
              :max        => (max if supports_max)
            }.compact
          ),
          :next_run => true
        )
        vm_service.update(
          OvirtSDK4::Vm.new(
            :memory => virtual
          )
        )
      else
        vm_service.update(
          OvirtSDK4::Vm.new(
            :memory        => virtual,
            :memory_policy => {
              :guaranteed => guaranteed,
              :max        => (max if supports_max)
            }.compact
          )
        )
      end
    end

    #
    # Adjusts the new requested virtual memory of a virtual machine so that it satisfies the constraints imposed
    # by the engine.
    #
    # @param vm [OvirtSDK4::Vm] The current representation of the virtual machine.
    # @param memory [Integer] The new amount of memory requested by the user.
    # @return [Integer] The amount of memory requested by the user adjusted so that it satisfies the constrains
    #   imposed by the engine.
    #
    def calculate_adjusted_virtual_memory(vm, memory)
      # Initially there is no need for adjustment:
      adjusted = memory

      # If the virtual machine is running then the difference in memory has to be a multiple of 256 MiB, otherwise
      # the engine will not perform the hot plug of the new memory. The reason for this is that hot plugging of
      # memory is performed adding a new virtual DIMM to the virtual machine, and the size of the virtual DIMM
      # is 256 MiB. This means that we need to round the difference up to the closest multiple of 256 MiB.
      if vm.status == OvirtSDK4::VmStatus::UP
        delta = memory - vm.memory
        remainder = delta % HOT_PLUG_DIMM_SIZE
        if remainder > 0
          adjustment = HOT_PLUG_DIMM_SIZE - remainder
          adjusted = memory + adjustment
          _log.info(
            "The change in virtual memory of virtual machine '#{vm.name}' needs to be a multiple of " \
            "#{HOT_PLUG_DIMM_SIZE / 1.megabyte} MiB, so it will be adjusted to #{adjusted / 1.megabyte} MiB."
          )
        end
      end

      # Return the adjusted memory:
      adjusted
    end

    #
    # Adjusts the guaranteed memory of a virtual machie so that it satisfies the constraints imposed by the
    # engine.
    #
    # @param vm [OvirtSDK4::Vm] The current representation of the virtual machine.
    # @param memory [Integer] The new amount of memory requested by the user (and maybe already adjusted).
    # @return [Integer] The amount of guarantted memory to request so that it satisfies the constraints imposed by
    #   the engine.
    #
    def calculate_adjusted_guaranteed_memory(vm, memory)
      # Get the current amount of guaranteed memory:
      current = vm.memory_policy.guaranteed

      # Initially there is no need for adjustment:
      adjusted = current

      # The engine requires that the virtual memory is bigger or equal than the guaranteed memory at any given
      # time. Therefore, we need to adjust the guaranteed memory so that it is the minimum of the previous
      # guaranteed memory and the new virtual memory.
      if current > memory
        adjusted = memory
        _log.info(
          "The guaranteed physical memory of virtual machine '#{vm.name}' needs to be less or equal than the " \
          "virtual memory, so it will be adjusted to #{adjusted / 1.megabyte} MiB."
        )
      end

      # Return the adjusted guaranteed memory:
      adjusted
    end

    #
    # Adjusts the max memory of a virtual machine so that it satisfies the constraints imposed by the
    # engine. The max memory is supported since version 4.1 and limited to 1TB according to the UI limits
    # defined for ovirt provider.
    #
    # @param vm [OvirtSDK4::Vm] The current representation of the virtual machine.
    # @param memory [Integer] The new amount of memory requested by the user.
    # @return [Integer] The amount of max memory to request so that it satisfies the constraints imposed by
    #   the engine.
    #
    def calculate_max_memory(vm, memory)
      max = vm.memory_policy&.max || memory
      if memory >= 1.terabyte
        max = memory
      else
        max = [memory * 4, 1.terabyte].min if memory > max
      end

      max
    end

    #
    # Adds disks to a virtual machine.
    #
    # @param vm_service [OvirtSDK4::VmsService] The service that manages the virtual machine.
    # @param disk_specs [Hash] The specification of the disks to add.
    #
    def add_vm_disks(vm_service, disk_specs)
      storage_spec = disk_specs[:storage]
      attachments_service = vm_service.disk_attachments_service
      disk_specs[:disks].each do |disk_spec|
        attachment = prepare_vm_disk_attachment(disk_spec, storage_spec)
        attachments_service.add(attachment)
      end
    end

    #
    # Prepares a disk attachment for adding a new disk to a virtual machine.
    #
    # @param disk_spec [Hash] The specification of the disk to add.
    # @param storage_spec [Hash] The specification of the storage to use.
    #
    def prepare_vm_disk_attachment(disk_spec, storage_spec)
      disk_spec = disk_spec.symbolize_keys
      attachment_builder = ManageIQ::Providers::Redhat::InfraManager::DiskAttachmentBuilder.new(
        :size_in_mb       => disk_spec[:disk_size_in_mb],
        :storage          => storage_spec,
        :name             => disk_spec[:disk_name],
        :thin_provisioned => disk_spec[:thin_provisioned],
        :bootable         => disk_spec[:bootable],
      )
      attachment_builder.disk_attachment
    end

    #
    # Removes disks from a virtual machine.
    #
    # @param vm_service [OvirtSDK4::VmsService] The service that manages the virtual machine.
    # @param disk_specs [Array<Hash>] The specifications of the disks to remove.
    #
    def remove_vm_disks(vm_service, disk_specs)
      attachments_service = vm_service.disk_attachments_service
      disk_specs.each do |disk_spec|
        attachment_service = attachments_service.attachment_service(disk_spec['disk_name'])
        attachment_service.remove(:detach_only => !disk_spec['delete_backing'])
      end
    end
  end
end

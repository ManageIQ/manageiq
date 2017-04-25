module ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Strategies
  class V3
    include Vmdb::Logging

    attr_reader :ext_management_system

    def initialize(args)
      @ext_management_system = args[:ems]
    end

    def get
      self
    end

    # Event parsing

    def username_by_href(href)
      ext_management_system.with_provider_connection do |rhevm|
        Ovirt::User.find_by_href(rhevm, href).try(:[], :user_name)
      end
    end

    def cluster_name_href(href)
      ext_management_system.with_provider_connection do |rhevm|
        Ovirt::Cluster.find_by_href(rhevm, href).try(:[], :name)
      end
    end

    # Provisioning
    def get_host_proxy(host, connection)
      connection ||= ext_management_system.connect
      host_proxy = connection.get_resource_by_ems_ref(host.ems_ref)
      GeneralUpdateMethodNamesDecorator.new(host_proxy)
    end

    def clone_completed?(args)
      source = args[:source]
      phase_context = args[:phase_context]
      logger = args[:logger]
      # TODO: shouldn't this error out the provision???
      return true if phase_context[:clone_task_ref].nil?

      source.with_provider_connection do |rhevm|
        status = rhevm.status(phase_context[:clone_task_ref])
        logger.info("Clone is #{status}")
        status == 'complete'
      end
    end

    def destination_image_locked?(vm)
      vm.with_provider_object do |rhevm_vm|
        return false if rhevm_vm.nil?
        rhevm_vm.attributes.fetch_path(:status, :state) == "image_locked"
      end
    end

    def populate_phase_context(phase_context, vm)
      phase_context[:new_vm_ems_ref] = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(vm[:href])
      phase_context[:clone_task_ref] = vm.creation_status_link
    end

    def nics_for_vm(vm)
      vm.with_provider_object do |rhevm_vm|
        rhevm_vm.nics.collect { |n| NicsDecorator.new(n) }
      end
    end

    def cluster_find_network_by_name(href, network_name)
      ext_management_system.with_provider_connection do |rhevm|
        Ovirt::Cluster.find_by_href(rhevm, href).try(:find_network_by_name, network_name)
      end
    end

    def configure_vnic(args)
      vnic = args[:vnic]

      options = {
        :name        => args[:nic_name],
        :interface   => args[:interface],
        :network_id  => args[:network][:id],
        :mac_address => args[:mac_addr],
      }.delete_blanks

      args[:logger].info("with options: <#{options.inspect}>")

      if vnic.nil?
        args[:vm].with_provider_object do |rhevm_vm|
          rhevm_vm.create_nic(options)
        end
      else
        vnic.apply_options!(options)
      end
    end

    def powered_off_in_provider?(vm)
      vm.with_provider_object(&:status)[:state] == "down"
    end

    def powered_on_in_provider?(vm)
      vm.with_provider_object(&:status)[:state] == "up"
    end

    def vm_boot_from_cdrom(operation, name)
      operation.get_provider_destination.boot_from_cdrom(name)
    rescue Ovirt::VmNotReadyToBoot
      raise OvirtServices::VmNotReadyToBoot
    end

    def vm_boot_from_network(operation)
      operation.get_provider_destination.boot_from_network
    rescue Ovirt::VmNotReadyToBoot
      raise OvirtServices::VmNotReadyToBoot
    end

    def get_template_proxy(template, connection)
      connection ||= ext_management_system.connect
      template_proxy = connection.get_resource_by_ems_ref(template.ems_ref)
      GeneralUpdateMethodNamesDecorator.new(template_proxy)
    end

    def get_vm_proxy(vm, connection)
      connection ||= ext_management_system.connect
      vm_proxy = connection.get_resource_by_ems_ref(vm.ems_ref)
      GeneralUpdateMethodNamesDecorator.new(vm_proxy)
    end

    def collect_disks_by_hrefs(disks)
      vm_disks = []

      ext_management_system.try(:with_provider_connection) do |rhevm|
        disks.each do |disk|
          begin
            vm_disks << Ovirt::Disk.find_by_href(rhevm, disk)
          rescue Ovirt::MissingResourceError
            nil
          end
        end
      end
      vm_disks
    end

    def shutdown_guest(operation)
      operation.with_provider_object(&:shutdown)
    rescue Ovirt::VmIsNotRunning
    end

    def start_clone(source, clone_options, phase_context)
      source.with_provider_object do |rhevm_template|
        vm = rhevm_template.create_vm(clone_options)
        populate_phase_context(phase_context, vm)
      end
    end

    def vm_start(vm, cloud_init)
      vm.with_provider_object do |rhevm_vm|
        rhevm_vm.start { |action| action.use_cloud_init(true) if cloud_init }
      end
    rescue Ovirt::VmAlreadyRunning
    end

    def vm_stop(vm)
      vm.with_provider_object(&:stop)
    rescue Ovirt::VmIsNotRunning
    end

    def vm_suspend(vm)
      vm.with_provider_object(&:suspend)
    end

    def vm_reconfigure(vm, options = {})
      log_header = "EMS: [#{ext_management_system.name}] #{vm.class.name}: id [#{vm.id}], name [#{vm.name}], ems_ref [#{vm.ems_ref}]"
      spec = options[:spec]

      _log.info("#{log_header} Started...")

      vm.with_provider_object do |rhevm_vm|
        update_vm_memory(rhevm_vm, spec["memoryMB"] * 1.megabyte) if spec["memoryMB"]

        cpu_options = {}
        cpu_options[:cores] = spec["numCoresPerSocket"] if spec["numCoresPerSocket"]
        cpu_options[:sockets] = spec["numCPUs"] / (cpu_options[:cores] || vm.cpu_cores_per_socket) if spec["numCPUs"]

        rhevm_vm.cpu_topology = cpu_options if cpu_options.present?
      end

      _log.info("#{log_header} Completed.")
    end

    class NicsDecorator < SimpleDelegator
      def name
        self[:name]
      end

      def network
        id = self[:network][:id]
        OpenStruct.new(:id => id)
      end
    end

    class GeneralUpdateMethodNamesDecorator < SimpleDelegator
      def method_missing(method_name, *args)
        str_method_name = method_name.to_s
        if str_method_name =~ /update_.*!/
          attribute_to_update = str_method_name.split("update_")[1].delete('!')
          send("#{attribute_to_update}=", *args)
        else
          # This is requied becasue of Ovirt::Vm strage behaviour - while rhevm.respond_to?(:nics)
          # returns false, rhevm.nics actually works.
          begin
            __getobj__.send(method_name, *args)
          rescue NoMethodError
            super
          end
        end
      end
    end

    private

    #
    # Hot plug of virtual memory has to be done in quanta of this size. Actually this is configurable in the
    # engine, using the `HotPlugMemoryMultiplicationSizeMb` configuration parameter, but it is very unlikely
    # that it will change.
    #
    HOT_PLUG_DIMM_SIZE = 256.megabyte.freeze

    def update_vm_memory(vm, virtual)
      # Adjust the virtual and guaranteed memory:
      virtual = calculate_adjusted_virtual_memory(vm, virtual)
      guaranteed = calculate_adjusted_guaranteed_memory(vm, virtual)

      # If the virtual machine is running we need to update first the configuration that will be used during the
      # next run, as the guaranteed memory can't be changed for the running virtual machine.
      state = vm.attributes.fetch_path(:status, :state)
      if state == 'up'
        vm.update_memory(virtual, guaranteed, :next_run => true)
        vm.update_memory(virtual, nil)
      else
        vm.update_memory(virtual, guaranteed)
      end
    end

    #
    # Adjusts the new requested virtual memory of a virtual machine so that it satisfies the constraints imposed
    # by the engine.
    #
    # @param vm [Hash] The current representation of the virtual machine.
    #
    # @param requested [Integer] The new amount of virtual memory requested by the user.
    #
    # @return [Integer] The amount of virtual memory requested by the user adjusted so that it satisfies the constrains
    #   imposed by the engine.
    #
    def calculate_adjusted_virtual_memory(vm, requested)
      # Get the current state of the virtual machine, and the current amount of virtual memory:
      attributes = vm.attributes
      name = attributes.fetch_path(:name)
      state = attributes.fetch_path(:status, :state)
      current = attributes.fetch_path(:memory)

      # Initially there is no need for adjustment:
      adjusted = requested

      # If the virtual machine is running then the difference in memory has to be a multiple of 256 MiB, otherwise
      # the engine will not perform the hot plug of the new memory. The reason for this is that hot plugging of
      # memory is performed adding a new virtual DIMM to the virtual machine, and the size of the virtual DIMM
      # is 256 MiB. This means that we need to round the difference up to the closest multiple of 256 MiB.
      if state == 'up'
        delta = requested - current
        remainder = delta % HOT_PLUG_DIMM_SIZE
        if remainder > 0
          adjustment = HOT_PLUG_DIMM_SIZE - remainder
          adjusted = requested + adjustment
          _log.info(
            "The change in virtual memory of virtual machine '#{name}' needs to be a multiple of " \
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
    # @param vm [Hash] The current representation of the virtual machine.
    #
    # @param virtual [Integer] The new amount of virtual memory requested by the user (and maybe already adjusted).
    #
    # @return [Integer] The amount of guarantted memory to request so that it satisfies the constraints imposed by
    #   the engine.
    #
    def calculate_adjusted_guaranteed_memory(vm, virtual)
      # Get the current amount of guaranteed memory:
      attributes = vm.attributes
      name = attributes.fetch_path(:name)
      current = attributes.fetch_path(:memory_policy, :guaranteed)

      # Initially there is no need for adjustment:
      adjusted = current

      # The engine requires that the virtual memory is bigger or equal than the guaranteed memory at any given
      # time. Therefore, we need to adjust the guaranteed memory so that it is the minimum of the previous
      # guaranteed memory and the new virtual memory.
      if current > virtual
        adjusted = virtual
        _log.info(
          "The guaranteed physical memory of virtual machine '#{name}' needs to be less or equal than the virtual " \
          "memory, so it will be adjusted to #{adjusted / 1.megabyte} MiB."
        )
      end

      # Return the adjusted guaranteed memory:
      adjusted
    end
  end
end

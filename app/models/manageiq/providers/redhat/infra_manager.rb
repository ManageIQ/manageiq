class ManageIQ::Providers::Redhat::InfraManager < ManageIQ::Providers::InfraManager
  require_nested  :EventCatcher
  require_nested  :EventParser
  require_nested  :RefreshWorker
  require_nested  :MetricsCapture
  require_nested  :MetricsCollectorWorker
  require_nested  :Host
  require_nested  :Provision
  require_nested  :ProvisionViaIso
  require_nested  :ProvisionViaPxe
  require_nested  :ProvisionWorkflow
  require_nested  :Refresh
  require_nested  :Template
  require_nested  :Vm
  include_concern :ApiIntegration
  include_concern :VmImport

  supports :provisioning
  supports :refresh_new_target

  #
  # Hot plug of virtual memory has to be done in quanta of this size. Actually this is configurable in the
  # engine, using the `HotPlugMemoryMultiplicationSizeMb` configuration parameter, but it is very unlikely
  # that it will change.
  #
  HOT_PLUG_DIMM_SIZE = 256.megabyte.freeze

  def refresher
    Refresh::RefresherBuilder.new(self).build
  end

  def self.ems_type
    @ems_type ||= "rhevm".freeze
  end

  def self.description
    @description ||= "Red Hat Virtualization Manager".freeze
  end

  def self.default_blacklisted_event_names
    %w(
      UNASSIGNED
      USER_REMOVE_VG
      USER_REMOVE_VG_FAILED
      USER_VDC_LOGIN
      USER_VDC_LOGOUT
      USER_VDC_LOGIN_FAILED
    )
  end

  def self.without_iso_datastores
    includes(:iso_datastore).where(:iso_datastores => {:id => nil})
  end

  def self.any_without_iso_datastores?
    without_iso_datastores.count > 0
  end

  def self.event_monitor_class
    self::EventCatcher
  end

  def host_quick_stats(host)
    qs = {}
    with_provider_connection(:version => 4) do |connection|
      stats_list = connection.system_service.hosts_service.host_service(host.uid_ems)
                             .statistics_service.list
      qs["overallMemoryUsage"] = stats_list.detect { |x| x.name == "memory.used" }
                                           .values.first.datum
      qs["overallCpuUsage"] = stats_list.detect { |x| x.name == "cpu.load.avg.5m" }
                                        .values.first.datum
    end
    qs
  end

  def self.provision_class(via)
    case via
    when "iso" then self::ProvisionViaIso
    when "pxe" then self::ProvisionViaPxe
    else            self::Provision
    end
  end

  def vm_reconfigure(vm, options = {})
    log_header = "EMS: [#{name}] #{vm.class.name}: id [#{vm.id}], name [#{vm.name}], ems_ref [#{vm.ems_ref}]"
    spec       = options[:spec]

    vm.with_provider_object do |rhevm_vm|
      _log.info("#{log_header} Started...")
      update_vm_memory(rhevm_vm, spec["memoryMB"] * 1.megabyte) if spec["memoryMB"]

      cpu_options = {}
      cpu_options[:cores]   = spec["numCoresPerSocket"] if spec["numCoresPerSocket"]
      cpu_options[:sockets] = spec["numCPUs"] / (cpu_options[:cores] || vm.cpu_cores_per_socket) if spec["numCPUs"]

      rhevm_vm.cpu_topology = cpu_options if cpu_options.present?
    end

    # Removing disks
    remove_disks(spec["disksRemove"], vm) if spec["disksRemove"]

    # Adding disks
    add_disks(spec["disksAdd"], vm) if spec["disksAdd"]

    _log.info("#{log_header} Completed.")
  end

  def add_disks(add_disks_spec, vm)
    storage = add_disks_spec[:storage]
    with_disk_attachments_service(vm) do |service|
      add_disks_spec[:disks].each { |disk_spec| service.add(prepare_disk(disk_spec, storage)) }
    end
  end

  # prepare disk attachment request payload of adding disk for reconfigure vm
  def prepare_disk(disk_spec, storage)
    disk_spec = disk_spec.symbolize_keys
    da_options = {
      :size_in_mb       => disk_spec[:disk_size_in_mb],
      :storage          => storage,
      :name             => disk_spec[:disk_name],
      :thin_provisioned => disk_spec[:thin_provisioned],
      :bootable         => disk_spec[:bootable],
    }

    disk_attachment_builder = DiskAttachmentBuilder.new(da_options)
    disk_attachment_builder.disk_attachment
  end

  # add disk to a virtual machine for a request arrived from an automation call
  def vm_add_disk(vm, options = {})
    storage = options[:datastore] || vm.storage
    raise _("Data Store does not exist, unable to add disk") unless storage

    da_options = {
      :size_in_mb       => options[:diskSize],
      :storage          => storage,
      :name             => options[:diskName],
      :thin_provisioned => options[:thinProvisioned],
      :bootable         => options[:bootable],
      :interface        => options[:interface]
    }

    disk_attachment_builder = DiskAttachmentBuilder.new(da_options)
    with_disk_attachments_service(vm) do |service|
      service.add(disk_attachment_builder.disk_attachment)
    end
  end

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

  def remove_disks(disks, vm)
    with_disk_attachments_service(vm) do |service|
      disks.each do |disk|
        service.attachment_service(disk["disk_name"]).remove(:detach_only => !disk["delete_backing"])
      end
    end
  end

  def vm_migrate(vm, options = {})
    host_id = URI(options[:host]).path.split('/').last

    migration_options = {
      :host => {
        :id => host_id
      }
    }

    with_version4_vm_service(vm) do |service|
      service.migrate(migration_options)
    end
  end

  def unsupported_migration_options
    [:storage, :respool, :folder, :datacenter, :host_filter, :cluster]
  end

  # Migrations are supposed to work only in one cluster. If more VMs are going
  # to be migrated, all have to live on the same cluster, otherwise they can
  # not be migrated together.
  def supports_migrate_for_all?(vms)
    vms.map(&:ems_cluster).uniq.compact.size == 1
  end

  private

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

class ManageIQ::Providers::Redhat::InfraManager < ManageIQ::Providers::InfraManager
  require_nested  :EventCatcher
  require_nested  :EventParser
  require_nested  :RefreshWorker
  require_nested  :RefreshParser
  require_nested  :MetricsCapture
  require_nested  :MetricsCollectorWorker
  require_nested  :Host
  require_nested  :Provision
  require_nested  :ProvisionViaIso
  require_nested  :ProvisionViaPxe
  require_nested  :ProvisionWorkflow
  require_nested  :Refresher
  require_nested  :Template
  require_nested  :Vm
  include_concern :ApiIntegration
  include_concern :VmImport

  supports :provisioning
  supports :refresh_new_target

  def self.ems_type
    @ems_type ||= "rhevm".freeze
  end

  def self.description
    @description ||= "Red Hat Enterprise Virtualization Manager".freeze
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
    ems_storage_uid = add_disks_spec["ems_storage_uid"]
    with_disk_attachments_service(vm) do |service|
      add_disks_spec["disks"].each { |disk_spec| service.add(prepare_disk(disk_spec, ems_storage_uid)) }
    end
  end

  def prepare_disk(disk_spec, ems_storage_uid)
    {
      :bootable  => disk_spec["bootable"],
      :interface => "VIRTIO",
      :disk      => {
        :provisioned_size => disk_spec["disk_size_in_mb"].to_i * 1024 * 1024,
        :sparse           => disk_spec["thin_provisioned"],
        :format           => disk_spec["format"],
        :storage_domain   => {:id => ems_storage_uid}
      }
    }
  end

  # RHEVM requires that the memory of the VM will be bigger or equal to the reserved memory at any given time.
  # Therefore, increasing the memory of the vm should precede to updating the reserved memory, and the opposite:
  # Decreasing the memory to a lower value than the reserved memory requires first to update the reserved memory
  def update_vm_memory(rhevm_vm, memory)
    if memory > rhevm_vm.attributes.fetch_path(:memory)
      rhevm_vm.memory = memory
      rhevm_vm.memory_reserve = memory
    else
      rhevm_vm.memory_reserve = memory
      rhevm_vm.memory = memory
    end
  end

  def remove_disks(disks, vm)
    with_disk_attachments_service(vm) do |service|
      disks.each { |disk_id| service.attachment_service(disk_id).remove }
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
    [:storage, :respool, :folder, :datacenter, :host_filter]
  end
end

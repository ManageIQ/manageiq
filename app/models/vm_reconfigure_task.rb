class VmReconfigureTask < MiqRequestTask
  alias_attribute :vm, :source

  validate :validate_request_type, :validate_state

  AUTOMATE_DRIVES = false

  def self.base_model
    VmReconfigureTask
  end

  def self.get_description(req)
    options = req.options

    msg = []
    msg << build_message(options, :vm_memory, "Memory: %d MB")
    msg << build_message(options, :number_of_sockets, "Processor Sockets: %d")
    msg << build_message(options, :cores_per_socket, "Processor Cores Per Socket: %d")
    msg << build_message(options, :number_of_cpus, "Total Processors: %d")
    msg << build_disk_message(options)
    msg << build_message(options, :disk_remove, "Remove Disks: %d", :length)
    msg << build_message(options, :disk_resize, "Resize Disks: %d", :length)
    msg << build_message(options, :network_adapter_add, "Add Network Adapters: %d", :length)
    msg << build_message(options, :network_adapter_remove, "Remove Network Adapters: %d", :length)
    msg << build_message(options, :network_adapter_edit, "Edit Network Adapters: %d", :length)
    msg << build_message(options, :cdrom_connect, "Attach CD/DVDs: %d", :length)
    msg << build_message(options, :cdrom_disconnect, "Detach CD/DVDs: %d", :length)
    "#{request_class::TASK_DESCRIPTION} for: #{resource_name(req)} - #{msg.compact.join(", ")}"
  end

  def self.build_message(options, key, message, modifier = nil)
    if options[key].present?
      value = options[key]
      value = value.send(modifier) if modifier
      message % value
    end
  end
  private_class_method :build_message

  def self.build_disk_message(options)
    if options[:disk_add].present?
      disk_sizes = options[:disk_add].collect { |d| d["disk_size_in_mb"].to_i.megabytes.to_s(:human_size) + ", Type: " + d["type"].to_s }
      "Add Disks: #{options[:disk_add].length} : #{disk_sizes.join(", ")} "
    end
  end
  private_class_method :build_disk_message

  def self.resource_name(req)
    return req.source.name if req.source
    return "Multiple VMs"  if req.options[:src_ids].length > 1

    # Single source has not been selected yet
    vm = Vm.find_by(:id => req.options[:src_ids])
    vm.nil? ? "" : vm.name
  end
  private_class_method :resource_name

  def after_request_task_create
    update_attribute(:description, get_description)
  end

  def do_request
    config = vm.build_config_spec(options)
    dump_obj(config, "#{_log.prefix} Config spec: ", $log, :info)
    vm.spec_reconfigure(config)

    if AUTOMATE_DRIVES
      update_and_notify_parent(:state => 'reconfigured', :message => "Finished #{request_class::TASK_DESCRIPTION}")
    else
      update_and_notify_parent(:state => 'finished', :message => "#{request_class::TASK_DESCRIPTION} complete")
    end
  end
end

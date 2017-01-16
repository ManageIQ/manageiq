class VmReconfigureTask < MiqRequestTask
  alias_attribute :vm, :source

  validate :validate_request_type, :validate_state

  AUTOMATE_DRIVES = false

  def self.base_model
    VmReconfigureTask
  end

  def self.get_description(req_obj)
    name = nil
    if req_obj.source.nil?
      # Single source has not been selected yet
      if req_obj.options[:src_ids].length == 1
        v = Vm.find_by(:id => req_obj.options[:src_ids].first)
        name = v.nil? ? "" : v.name
      else
        name = "Multiple VMs"
      end
    else
      name = req_obj.source.name
    end

    new_settings = []
    unless req_obj.options[:vm_memory].blank?
      new_settings << "Memory: #{req_obj.options[:vm_memory].to_i} MB"
    end
    new_settings << "Processor Sockets: #{req_obj.options[:number_of_sockets].to_i}" unless req_obj.options[:number_of_sockets].blank?
    new_settings << "Processor Cores Per Socket: #{req_obj.options[:cores_per_socket].to_i}" unless req_obj.options[:cores_per_socket].blank?
    new_settings << "Total Processors: #{req_obj.options[:number_of_cpus].to_i}" unless req_obj.options[:number_of_cpus].blank?
    new_settings << "Add Disks: #{req_obj.options[:disk_add].length}" unless req_obj.options[:disk_add].blank?
    new_settings << "Remove Disks: #{req_obj.options[:disk_remove].length}" unless req_obj.options[:disk_remove].blank?
    "#{request_class::TASK_DESCRIPTION} for: #{name} - #{new_settings.join(", ")}"
  end

  def after_request_task_create
    update_attribute(:description, get_description)
  end

  def do_request
    config = vm.build_config_spec(options)
    dumpObj(config, "#{_log.prefix} Config spec: ", $log, :info)
    vm.spec_reconfigure(config)

    if AUTOMATE_DRIVES
      update_and_notify_parent(:state => 'reconfigured', :message => "Finished #{request_class::TASK_DESCRIPTION}")
    else
      update_and_notify_parent(:state => 'finished', :message => "#{request_class::TASK_DESCRIPTION} complete")
      #        call_automate_event('vm_provision_postprocessing')
    end
  end
end

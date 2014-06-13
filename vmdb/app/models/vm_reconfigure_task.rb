class VmReconfigureTask < MiqRequestTask
  alias_attribute :vm, :source

  include ReportableMixin

  validates_inclusion_of :request_type, :in => self.request_class::REQUEST_TYPES,                          :message => "should be #{self.request_class::REQUEST_TYPES.join(", ")}"
  validates_inclusion_of :state,        :in => %w{ pending finished } + self.request_class::ACTIVE_STATES, :message => "should be pending, #{self.request_class::ACTIVE_STATES.join(", ")} or finished"

  AUTOMATE_DRIVES  = false

  def self.base_model
    VmReconfigureTask
  end

  def self.get_description(req_obj)
    name = nil
    if req_obj.source.nil?
      # Single source has not been selected yet
      if req_obj.options[:src_ids].length == 1
        v = Vm.find_by_id(req_obj.options[:src_ids].first)
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
    new_settings << "Processors: #{req_obj.options[:number_of_cpus].to_i}" unless req_obj.options[:number_of_cpus].blank?
    return "#{self.request_class::TASK_DESCRIPTION} for: #{name} - #{new_settings.join(", ")}"
  end

  def after_request_task_create
    self.update_attribute(:description, self.get_description)
  end

  def do_request
    log_header = "MIQ(#{self.class.name}.do_request)"

    config = self.build_config_spec
    self.dumpObj(config, "#{log_header} Config spec: ", $log, :info)
    self.vm.spec_reconfigure(config)

    if AUTOMATE_DRIVES
      update_and_notify_parent(:state => 'reconfigured', :message => "Finished #{self.request_class::TASK_DESCRIPTION}")
    else
      update_and_notify_parent(:state => 'finished', :message => "#{self.request_class::TASK_DESCRIPTION} complete")
#        call_automate_event('vm_provision_postprocessing')
    end
  end

  def build_config_spec
    VimHash.new("VirtualMachineConfigSpec") do |vmcs|
      set_spec_option(vmcs, :memoryMB, :vm_memory,      nil, :to_i)
      set_spec_option(vmcs, :numCPUs,  :number_of_cpus, nil, :to_i)
    end
  end

  # Set the value if it is not nil
  def set_spec_option(obj, property, key, default_value=nil, modifier=nil, override_value=nil)
    log_header = "MiqProvision.set_spec_option"
    if key.nil?
      value = get_option(nil, override_value)
    else
      value = override_value.nil? ? get_option(key) : override_value
    end
    value = default_value if value.nil?
    unless value.nil?
      # Modifier is a method like :to_s or :to_i
      value = value.to_s if [true,false].include?(value)
      value = value.send(modifier) unless modifier.nil?
      $log.info "#{log_header} #{property} was set to #{value} (#{value.class})"
      obj.send("#{property}=", value)
    else
      value = obj.send("#{property}")
      if value.nil?
        $log.info "#{log_header} #{property} was NOT set due to nil"
      else
        $log.info "#{log_header} #{property} inheriting value from spec: #{value} (#{value.class})"
      end
    end
  end
end

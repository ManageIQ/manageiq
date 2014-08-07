class VmReconfigureRequest < MiqRequest

  TASK_DESCRIPTION  = 'VM Reconfigure'
  SOURCE_CLASS_NAME = 'VmOrTemplate'
  REQUEST_TYPES     = %w{ vm_reconfigure }
  ACTIVE_STATES     = %w{ reconfigured } + self.base_class::ACTIVE_STATES

  validates_inclusion_of :request_type,   :in => REQUEST_TYPES,                          :message => "should be #{REQUEST_TYPES.join(", ")}"
  validates_inclusion_of :request_state,  :in => %w{ pending finished } + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  default_value_for :request_type, REQUEST_TYPES.first
  default_value_for :message,      "#{TASK_DESCRIPTION} - Request Created"
  default_value_for(:requester)    { |r| r.get_user }

  def self.create_request(values, requester_id, auto_approve=false)
    event_message = "#{TASK_DESCRIPTION} requested by <#{requester_id}>"
    super(values, requester_id, auto_approve, REQUEST_TYPES.first, SOURCE_CLASS_NAME, event_message)
  end

  def self.update_request(request, values, requester_id)
    event_message = "#{TASK_DESCRIPTION} request was successfully updated by <#{requester_id}>"
    super(request, values, requester_id, SOURCE_CLASS_NAME, event_message)
  end

  def self.request_limits(options)
    # Memory values are in megabytes
    result = {
      :min__number_of_cpus => 1,
      :max__number_of_cpus => nil,
      :min__vm_memory      => 4,
      :max__vm_memory      => (255 * 1.gigabyte) / 1.megabyte
    }

    # TODO: Add logic to determine :max__vm_memory value based on selected VMs/Hosts
    options[:src_ids].to_miq_a.each do |idx|
      vm = Vm.find_by_id(idx)
      unless (host = vm.host).nil?
        result[:max__number_of_cpus] = result[:max__number_of_cpus].nil? ? host.hardware.logical_cpus : [host.hardware.logical_cpus, result[:max__number_of_cpus]].min
      end
    end
    result[:max__number_of_cpus] = 1 if result[:max__number_of_cpus].nil?
    return result
  end

  def self.validate_request(options)
    errors = []
    limits = self.request_limits(options)

    # Check if memory value is divisible by 4 and within the allowed limits
    mem = options[:vm_memory]
    unless mem.blank?
      mem = mem.to_i
      errors << "Memory value must be less than #{limits[:max__vm_memory]} MB.  Current value: #{mem} MB" if mem > limits[:max__vm_memory]
      errors << "Memory value must be greater than #{limits[:min__vm_memory]} MB.  Current value: #{mem} MB" if mem < limits[:min__vm_memory]
      errors << "Memory value must be divisible by 4.  Current value: #{mem}" if mem.modulo(4) != 0
    end

    # Check if cpu value is within the allowed limits
    cpus = options[:number_of_cpus]
    unless cpus.blank?
      cpus = cpus.to_i
      errors << "Processor value must be less than #{limits[:max__number_of_cpus]}.  Current value: #{cpus}"    if cpus > limits[:max__number_of_cpus]
      errors << "Processor value must be greater than #{limits[:min__number_of_cpus]}.  Current value: #{cpus}" if cpus < limits[:min__number_of_cpus]
    end

    return false if errors.blank?
    return errors
  end

  def my_role
    'ems_operations'
  end

end

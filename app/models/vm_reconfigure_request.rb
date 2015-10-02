class VmReconfigureRequest < MiqRequest
  TASK_DESCRIPTION  = 'VM Reconfigure'
  SOURCE_CLASS_NAME = 'Vm'
  ACTIVE_STATES     = %w( reconfigured ) + base_class::ACTIVE_STATES

  validates_inclusion_of :request_state,  :in => %w( pending finished ) + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  def self.request_limits(options)
    # Memory values are in megabytes
    default_max_vm_memory = 255.gigabyte / 1.megabyte
    result = {
      :min__number_of_cpus   => 1,
      :max__number_of_cpus   => nil,
      :min__vm_memory        => 4,
      :max__vm_memory        => nil,
      :min__cores_per_socket => 1,
      :max__cores_per_socket => nil,
      :max__total_vcpus      => nil
    }

    all_memory, all_vcpus, all_cores_per_socket, all_total_vcpus = [], [], [], []
    options[:src_ids].to_miq_a.each do |idx|
      vm = Vm.find_by_id(idx)
      all_vcpus << (vm.host ? vm.host.hardware.logical_cpus : vm.max_vcpus)
      all_memory << (vm.respond_to?(:max_memory_cpu) ? vm.max_memory_cpu : default_max_vm_memory)
      all_cores_per_socket << vm.max_cores_per_socket
      all_total_vcpus << vm.max_total_vcpus
    end

    result[:max__number_of_cpus] = all_vcpus.min
    result[:max__vm_memory]      = all_memory.min
    result[:max__cores_per_socket] = all_cores_per_socket.min
    result[:max__total_vcpus] = all_total_vcpus.min

    result[:max__number_of_cpus] = 1 if result[:max__number_of_cpus].nil?
    result[:max__cores_per_socket] = 1 if result[:max__cores_per_socket].nil?
    result[:max__vm_memory] ||= default_max_vm_memory
    result[:max__total_vcpus] = 1 if result[:max__number_of_cpus].nil? && result[:max__cores_per_socket].nil?
    result
  end

  def self.validate_request(options)
    errors = []
    limits = request_limits(options)

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

    # Check if cpu value is within the allowed limits
    cores = options[:cores_per_socket]
    unless cores.blank?
      cores = cores.to_i
      errors << "The Cores per Socket value must be less than #{limits[:max__cores_per_socket]}.  Current value: #{cores}"    if cores > limits[:max__cores_per_socket]
      errors << "The Cores per Socket value must be greater than #{limits[:min__cores_per_socket]}.  Current value: #{cores}" if cores < limits[:min__cores_per_socket]
    end

    # Check if the total number of cpu value is within the allowed limits
    unless cpus.blank? || cores.blank?
      total_vcpus = (cores * cpus)
      errors << "The total number of cpus must be less than #{limits[:max__total_vcpus]}.  Current value: #{total_vcpus}"    if total_vcpus > limits[:max__total_vcpus]
    end

    return false if errors.blank?
    errors
  end

  def my_zone
    vm = Vm.find_by(:id => options[:src_ids])
    vm.nil? ? super : vm.my_zone
  end

  def my_role
    'ems_operations'
  end
end

class VmReconfigureRequest < MiqRequest
  TASK_DESCRIPTION  = 'VM Reconfigure'
  SOURCE_CLASS_NAME = 'Vm'
  ACTIVE_STATES     = %w( reconfigured ) + base_class::ACTIVE_STATES

  validates_inclusion_of :request_state,  :in => %w( pending finished ) + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user
  include MiqProvisionQuotaMixin

  def self.request_limits(options)
    # Memory values are in megabytes
    default_max_vm_memory = 255.gigabyte / 1.megabyte
    result = {
      :min__number_of_sockets => 1,
      :max__number_of_sockets => nil,
      :min__vm_memory         => 4,
      :max__vm_memory         => nil,
      :min__cores_per_socket  => 1,
      :max__cores_per_socket  => nil,
      :min__total_vcpus       => 1,
      :max__total_vcpus       => nil
    }

    all_memory, all_vcpus, all_cores_per_socket, all_total_vcpus = [], [], [], []
    Array.wrap(options[:src_ids]).each do |idx|
      vm = Vm.find_by(:id => idx)
      all_vcpus            << (vm.host ? [vm.host.hardware.cpu_total_cores, vm.max_vcpus].min : vm.max_vcpus)
      all_cores_per_socket << (vm.host ? [vm.host.hardware.cpu_total_cores, vm.max_cpu_cores_per_socket].min : vm.max_cpu_cores_per_socket)
      all_total_vcpus      << (vm.host ? [vm.host.hardware.cpu_total_cores, vm.max_total_vcpus].min : vm.max_total_vcpus)
      all_memory << (vm.respond_to?(:max_memory_mb) ? vm.max_memory_mb : default_max_vm_memory)
    end

    result[:max__number_of_sockets] = all_vcpus.min
    result[:max__vm_memory]      = all_memory.min
    result[:max__cores_per_socket] = all_cores_per_socket.min
    result[:max__total_vcpus] = all_total_vcpus.min

    result[:max__number_of_sockets] ||= 1
    result[:max__cores_per_socket] ||= 1
    result[:max__vm_memory] ||= default_max_vm_memory
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
    cpus = options[:number_of_sockets]
    unless cpus.blank?
      cpus = cpus.to_i
      errors << "Processor value must be less than #{limits[:max__number_of_sockets]}.  Current value: #{cpus}"    if cpus > limits[:max__number_of_sockets]
      errors << "Processor value must be greater than #{limits[:min__number_of_sockets]}.  Current value: #{cpus}" if cpus < limits[:min__number_of_sockets]
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

  def self.make_request(request, values, requester, auto_approve = false)
    values[:request_type] = :vm_reconfigure

    ApplicationRecord.group_ids_by_region(values[:src_ids]).collect do |_region, ids|
      super(request, values.merge(:src_ids => ids), requester, auto_approve)
    end
  end

  def vm
    @vm ||= Vm.find_by(:id => options[:src_ids])
  end

  def my_zone
    vm.nil? ? super : vm.my_zone
  end

  def my_role(_action = nil)
    'ems_operations'
  end

  def my_queue_name
    vm.nil? ? super : vm.queue_name_for_ems_operations
  end
end

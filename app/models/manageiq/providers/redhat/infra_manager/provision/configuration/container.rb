module ManageIQ::Providers::Redhat::InfraManager::Provision::Configuration::Container
  private

  def configure_container_description(rhevm_vm)
    description = get_option(:vm_description)
    _log.info "Setting description to:<#{description.inspect}>"
    rhevm_vm.description = description
  end

  def configure_memory(rhevm_vm)
    vm_memory = get_option(:vm_memory).to_i * 1.megabyte
    return if vm_memory.zero?
    _log.info "Setting memory to:<#{vm_memory.inspect}>"
    rhevm_vm.memory = vm_memory
  end

  def configure_memory_reserve(rhevm_vm)
    memory_reserve = get_option(:memory_reserve).to_i.megabyte
    return if memory_reserve.zero?
    _log.info "Setting memory reserve to:<#{memory_reserve.inspect}>"
    rhevm_vm.memory_reserve = memory_reserve
  end

  def configure_cpu(rhevm_vm)
    sockets  = get_option(:number_of_sockets) || 1
    cores    = get_option(:cores_per_socket) || 1
    cpu_hash = {:cores => cores, :sockets => sockets}
    _log.info "Setting cpu to:<#{cpu_hash.inspect}>"
    rhevm_vm.cpu_topology = cpu_hash
  end

  def configure_host_affinity(rhevm_vm)
    return if dest_host.nil?
    _log.info("Setting Host Affinity to: #{dest_host.name} with ID=#{dest_host.id}")
    rhevm_vm.host_affinity = dest_host.ems_ref
  end
end

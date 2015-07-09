module ManageIQ::Providers::Redhat::InfraManager::Provision::Configuration::Container
  def set_container_description(description, vm = nil)
    _log.info "Setting description to:<#{description.inspect}>"
    vm ||= get_provider_destination
    vm.description = description
  end

  def set_container_memory(memory, vm = nil)
    _log.info "Setting memory to:<#{memory.inspect}>"
    vm ||= get_provider_destination
    vm.memory = memory
  end

  def set_container_memory_reserve(memory_reserve, vm = nil)
    _log.info "Setting memory reserve to:<#{memory_reserve.inspect}>"
    vm ||= get_provider_destination
    vm.memory_reserve = memory_reserve
  end

  def set_container_cpu(cpu_hash, vm = nil)
    _log.info "Setting cpu to:<#{cpu_hash.inspect}>"
    vm ||= get_provider_destination
    vm.cpu_topology = cpu_hash
  end
end

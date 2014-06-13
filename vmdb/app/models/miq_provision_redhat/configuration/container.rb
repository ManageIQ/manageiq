module MiqProvisionRedhat::Configuration::Container
  def set_container_description(description, vm = nil)
    $log.info "MIQ(#{self.class.name}#set_container_description) Setting description to:<#{description.inspect}>"
    vm ||= get_provider_destination
    vm.description = description
  end

  def set_container_memory(memory, vm = nil)
    $log.info "MIQ(#{self.class.name}#set_container_memory) Setting memory to:<#{memory.inspect}>"
    vm ||= get_provider_destination
    vm.memory = memory
  end

  def set_container_memory_reserve(memory_reserve, vm = nil)
    $log.info "MIQ(#{self.class.name}#set_container_memory) Setting memory reserve to:<#{memory_reserve.inspect}>"
    vm ||= get_provider_destination
    vm.memory_reserve = memory_reserve
  end

  def set_container_cpu(cpu_hash, vm = nil)
    $log.info "MIQ(#{self.class.name}#set_container_cpu) Setting cpu to:<#{cpu_hash.inspect}>"
    vm ||= get_provider_destination
    vm.cpu_topology = cpu_hash
  end
end

module MiqProvision::Description
  def set_description(vm, description)
    log_header = "MIQ(#{self.class.name}#set_description)"

    $log.info "#{log_header} Setting #{vm.class.base_model.name} description to #{description.inspect}"
    vm.description = description
  end
end

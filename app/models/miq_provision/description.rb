module MiqProvision::Description
  def set_description(vm, description)
    _log.info("Setting #{vm.class.base_model.name} description to #{description.inspect}")
    vm.description = description
  end
end

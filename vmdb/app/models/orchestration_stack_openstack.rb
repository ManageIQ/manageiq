class OrchestrationStackOpenstack < OrchestrationStack
  def raw_update_stack(options)
    ext_management_system.with_provider_connection(:service => "Orchestration") do |connection|
      connection.stacks.get(name, ems_ref).save(options)
    end
  end

  def raw_delete_stack
    ext_management_system.with_provider_connection(:service => "Orchestration") do |connection|
      connection.stacks.get(name, ems_ref).delete
    end
  end
end

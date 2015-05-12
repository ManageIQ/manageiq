class OrchestrationStackOpenstack < OrchestrationStack
  def raw_update_stack(options)
    options = {:service => "Orchestration"}
    options.merge!(:tenant_name => cloud_tenant.name) if cloud_tenant
    ext_management_system.with_provider_connection(options) do |connection|
      connection.stacks.get(name, ems_ref).save(options)
    end
  end

  def raw_delete_stack
    options = {:service => "Orchestration"}
    options.merge!(:tenant_name => cloud_tenant.name) if cloud_tenant
    ext_management_system.with_provider_connection(options) do |connection|
      connection.stacks.get(name, ems_ref).delete
    end
  end
end

class ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack < ::OrchestrationStack
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::InfraManager"

  def raw_update_stack(parameters)
    ext_management_system.with_provider_connection(:service => "Orchestration") do |connection|
      stack    = connection.stacks.get(name, ems_ref)
      template = connection.get_stack_template(stack).body

      connection.patch_stack(stack, 'template' => template, 'parameters' => parameters)
    end
  end

  def update_ready?
    # Update is possible only when in complete or failed state, otherwise API returns exception
    raw_status.first.end_with?("_COMPLETE", "_FAILED")
  end

  def raw_delete_stack
    options = {:service => "Orchestration"}
    options.merge!(:tenant_name => cloud_tenant.name) if cloud_tenant
    ext_management_system.with_provider_connection(options) do |service|
      service.stacks.get(name, ems_ref).try(:delete)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationDeleteError, err.to_s, err.backtrace
  end

  def raw_status
    ems = ext_management_system
    ems.with_provider_connection(:service => "Orchestration") do |service|
      raw_stack = service.stacks.get(name, ems_ref)
      raise MiqException::MiqOrchestrationStackNotExistError, "#{name} does not exist on #{ems.name}" unless raw_stack

      # TODO(lsmola) implement Status class, like in Cloud Manager, or make it common superclass
      [raw_stack.stack_status, raw_stack.stack_status_reason]
    end
  rescue MiqException::MiqOrchestrationStackNotExistError
    raise
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end
end

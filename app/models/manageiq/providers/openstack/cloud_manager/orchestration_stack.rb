class ManageIQ::Providers::Openstack::CloudManager::OrchestrationStack < ManageIQ::Providers::CloudManager::OrchestrationStack
  require_nested :Status

  def self.raw_create_stack(orchestration_manager, stack_name, template, options = {})
    create_options = {:stack_name => stack_name, :template => template.content}.merge(options).except(:tenant_name)
    connection_options = {:service => "Orchestration"}.merge(options.slice(:tenant_name))
    orchestration_manager.with_provider_connection(connection_options) do |service|
      service.stacks.new.save(create_options)["id"]
    end
  rescue => err
    _log.error "stack=[#{stack_name}], error: #{err}"
    raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
  end

  def raw_update_stack(template, options)
    update_options = {:template => template.content}.merge(options.except(:disable_rollback, :timeout_mins))
    connection_options = {:service => "Orchestration"}
    connection_options.merge!(:tenant_name => cloud_tenant.name) if cloud_tenant
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.stacks.get(name, ems_ref).save(update_options)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationUpdateError, err.to_s, err.backtrace
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
    options = {:service => "Orchestration"}
    options.merge!(:tenant_name => cloud_tenant.name) if cloud_tenant
    ems.with_provider_connection(options) do |service|
      raw_stack = service.stacks.get(name, ems_ref)
      raise MiqException::MiqOrchestrationStackNotExistError, "#{name} does not exist on #{ems.name}" unless raw_stack

      Status.new(raw_stack.stack_status, raw_stack.stack_status_reason)
    end
  rescue MiqException::MiqOrchestrationStackNotExistError
    raise
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end
end

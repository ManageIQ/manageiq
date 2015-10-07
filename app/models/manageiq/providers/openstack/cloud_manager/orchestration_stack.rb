class ManageIQ::Providers::Openstack::CloudManager::OrchestrationStack < ::OrchestrationStack
  require_dependency 'manageiq/providers/openstack/cloud_manager/orchestration_stack/status'

  def self.raw_create_stack(orchestration_manager, stack_name, template, options = {})
    create_options = {:stack_name => stack_name, :template => template.content}.merge(options).except(:cloud_tenant)
    connection_options = {:service => "Orchestration"}.merge(options.slice(:cloud_tenant))
    orchestration_manager.with_provider_connection(connection_options) do |service|
      service.stacks.new.save(create_options)["id"]
    end
  rescue => err
    _log.error "stack=[#{stack_name}], error: #{err}"
    raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
  end

  def raw_update_stack(options)
    connection_options = {:service => "Orchestration"}
    connection_options.merge!(:tenant_name => cloud_tenant.name) if cloud_tenant
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.stacks.get(name, ems_ref).save(options)
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
    ems.with_provider_connection(:service => "Orchestration") do |service|
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

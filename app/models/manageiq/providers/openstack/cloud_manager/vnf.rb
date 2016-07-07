class ManageIQ::Providers::Openstack::CloudManager::Vnf < ManageIQ::Providers::CloudManager::OrchestrationStack
  require_nested :Status

  def self.raw_create_stack(orchestration_manager, stack_name, template, options = {})
    create_options = {:vnf => {:name => stack_name, :vnfd_id => template.ems_ref}}
    create_options[:vnf][:attributes] = options[:attributes] if options[:attributes]

    connection_options = {:service => "NFV"}.merge(options.slice(:tenant_name))
    orchestration_manager.with_provider_connection(connection_options) do |service|
      service.vnfs.create(create_options).id
    end
  rescue => err
    _log.error "stack=[#{stack_name}], error: #{err}"
    raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
  end

  def raw_update_stack(_template, _options)
    # TODO(lsmola) implement updates
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationUpdateError, err.to_s, err.backtrace
  end

  def raw_delete_stack
    options = {:service => "NFV"}
    options[:tenant_name] = cloud_tenant.name if cloud_tenant
    ext_management_system.with_provider_connection(options) do |service|
      service.vnfs.destroy(ems_ref)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationDeleteError, err.to_s, err.backtrace
  end

  def raw_status
    ems = ext_management_system
    options = {:service => "NFV"}
    options[:tenant_name] = cloud_tenant.name if cloud_tenant
    ems.with_provider_connection(options) do |service|
      raw_stack = service.vnfs.get(ems_ref)
      raise MiqException::MiqOrchestrationStackNotExistError, "#{name} does not exist on #{ems.name}" unless raw_stack

      Status.new(raw_stack.status, nil)
    end
  rescue MiqException::MiqOrchestrationStackNotExistError
    raise
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end
end

class ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack < ::OrchestrationStack
  require_nested :Status

  def self.raw_create_stack(orchestration_manager, stack_name, template, options = {})
    orchestration_manager.with_provider_connection(:service => :CloudFormation) do |service|
      stack_options = options.merge(:stack_name => stack_name, :template_body => template.content)
      service.create_stack(stack_options).stack_id
    end
  rescue => err
    _log.error "stack=[#{stack_name}], error: #{err}"
    raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
  end

  def raw_update_stack(template, options)
    update_options = {:template_body => template.content}.merge(options.except(:disable_rollback, :timeout))
    ext_management_system.with_provider_connection(:service => :CloudFormation) do |service|
      service.stack(name).update(update_options)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationUpdateError, err.to_s, err.backtrace
  end

  def raw_delete_stack
    ext_management_system.with_provider_connection(:service => :CloudFormation) do |service|
      service.stack(name).try!(:delete)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationDeleteError, err.to_s, err.backtrace
  end

  def raw_status
    ext_management_system.with_provider_connection(:service => :CloudFormation) do |service|
      raw_stack = service.stack(name)
      Status.new(raw_stack.stack_status, raw_stack.stack_status_reason)
    end
  rescue => err
    if err.to_s =~ /[S|s]tack.+does not exist/
      raise MiqException::MiqOrchestrationStackNotExistError, "#{name} does not exist on #{ext_management_system.name}"
    end

    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end
end

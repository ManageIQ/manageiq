class ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack < ::OrchestrationStack
  require_dependency 'manageiq/providers/amazon/cloud_manager/orchestration_stack/status'

  def self.raw_create_stack(orchestration_manager, stack_name, template, options = {})
    orchestration_manager.with_provider_connection(:service => "CloudFormation") do |service|
      service.stacks.create(stack_name, template.content, options).stack_id
    end
  rescue => err
    _log.error "stack=[#{stack_name}], error: #{err}"
    raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
  end

  def raw_update_stack(options)
    ext_management_system.with_provider_connection(:service => "CloudFormation") do |service|
      service.stacks[name].update(options)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationUpdateError, err.to_s, err.backtrace
  end

  def raw_delete_stack
    ext_management_system.with_provider_connection(:service => "CloudFormation") do |service|
      service.stacks[name].try(:delete)
    end
  rescue => err
    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationDeleteError, err.to_s, err.backtrace
  end

  def raw_status
    ext_management_system.with_provider_connection(:service => "CloudFormation") do |service|
      raw_stack = service.stacks[name]
      Status.new(raw_stack.status, raw_stack.status_reason)
    end
  rescue => err
    if err.to_s =~ /[S|s]tack.+does not exist/
      raise MiqException::MiqOrchestrationStackNotExistError, "#{name} does not exist on #{ext_management_system.name}"
    end

    _log.error "stack=[#{name}], error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end
end

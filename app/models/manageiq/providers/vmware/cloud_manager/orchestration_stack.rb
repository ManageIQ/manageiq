class ManageIQ::Providers::Vmware::CloudManager::OrchestrationStack < ManageIQ::Providers::CloudManager::OrchestrationStack
  require_nested :Status

  def raw_status
    ems = ext_management_system
    ems.with_provider_connection do |service|
      raw_stack = service.vapps.get_single_vapp(ems_ref)
      raise MiqException::MiqOrchestrationStackNotExistError, "#{name} does not exist on #{ems.name}" unless raw_stack

      Status.new(raw_stack.human_status, nil)
    end
  rescue MiqException::MiqOrchestrationStackNotExistError
    raise
  rescue => err
    _log.error("stack=[#{name}], error: #{err}")
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end
end

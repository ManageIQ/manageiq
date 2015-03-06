#
# Description: This method checks to see if the stack has been provisioned
#   and whether the refresh has completed
#

def refresh_provider(service)
  provider = service.orchestration_manager

  $evm.log("info", "Refreshing provider #{provider.name}")
  provider.refresh
end

$evm.log("info", "Check orchestration provisioned")

service = $evm.root["service_template_provision_task"].destination

if $evm.state_var_exist? 'stack_deployed'
  # check whether refresh completed
  stack = $evm.vmdb('orchestration_stack').find_by_ems_ref(service.stack_ems_ref)

  $evm.log("info", "Check refresh status of stack (#{service.stack_name})")
  if stack
    $evm.root['ae_result'] = 'ok'
    stack.add_to_service(service)
    $evm.log("info", "Stack (#{stack.name}, id = #{stack.id}) has been added to vmdb")
  else
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '30.seconds'
  end
else
  # check whether the stack deployment completed
  status, reason = service.orchestration_stack_status
  case status.downcase
  when 'create_complete'
    refresh_provider(service)
    $evm.set_state_var('stack_deployed', true)
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '30.seconds'
  when 'rollback_complete'
    $evm.root['ae_result'] = 'error'
    $evm.root['ae_reason'] = 'Stack creation has been rolled back'
  when /failed$/
    $evm.root['ae_result'] = 'error'
    $evm.root['ae_reason'] = reason
  else
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  end
end

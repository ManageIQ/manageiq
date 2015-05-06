#
# Description: This method checks to see if the stack has been provisioned
#   and whether the refresh has completed
#

def refresh_provider(service)
  provider = service.orchestration_manager

  $evm.log("info", "Refreshing provider #{provider.name}")
  old_date = provider.last_refresh_date
  $evm.set_state_var('provider_last_refresh', old_date)
  provider.refresh
end

def refresh_may_have_completed?(service)
  provider = service.orchestration_manager
  provider.last_refresh_date > $evm.get_state_var('provider_last_refresh')
end

def check_deployed(service)
  $evm.log("info", "Check orchestration deployed")
  # check whether the stack deployment completed
  status, reason = service.orchestration_stack_status
  case status.downcase
  when 'create_complete'
    $evm.root['ae_result'] = 'ok'
  when 'rollback_complete'
    $evm.root['ae_result'] = 'error'
    $evm.root['ae_reason'] = 'Stack was rolled back'
  when /failed$/
    $evm.root['ae_result'] = 'error'
    $evm.root['ae_reason'] = reason
  else
    # deployment not done yet in provider
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
    return
  end

  $evm.log("info", "Stack deployment finished. Status: #{$evm.root['ae_result']}, reason: #{$evm.root['ae_reason']}")

  return unless service.stack_ems_ref
  $evm.set_state_var('deploy_result', $evm.root['ae_result'])
  $evm.set_state_var('deploy_reason', $evm.root['ae_reason'])

  refresh_provider(service)

  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '30.seconds'
end

def check_refreshed(service)
  $evm.log("info", "Check refresh status of stack (#{service.stack_name})")

  # check whether refresh has completed, and add stack to service if applicable
  # look for stack in vmdb if stack was successfully deployed
  # otherwise check provider's last refresh time stamp because the stack may not exist in provider

  stack = $evm.vmdb('orchestration_stack').find_by_ems_ref(service.stack_ems_ref)
  if stack
    $evm.root['ae_result'] = $evm.get_state_var('deploy_result')
    $evm.root['ae_reason'] = $evm.get_state_var('deploy_reason')
    stack.add_to_service(service)
    $evm.log("info", "Stack (#{stack.name}, id = #{stack.id}) has been added to VMDB")
  elsif $evm.get_state_var('deploy_result') == 'ok' || !refresh_may_have_completed?(service)
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '30.seconds'
  else
    $evm.root['ae_result'] = 'error'
    $evm.root['ae_reason'] = $evm.get_state_var('deploy_reason')
    $evm.log("info", "Refresh completed. No new stack was found")
  end
end

task = $evm.root["service_template_provision_task"]
service = task.destination
if $evm.state_var_exist?('provider_last_refresh')
  check_refreshed(service)
else
  check_deployed(service)
end
task.miq_request.user_message = $evm.root['ae_reason'] unless $evm.root['ae_reason'].blank?

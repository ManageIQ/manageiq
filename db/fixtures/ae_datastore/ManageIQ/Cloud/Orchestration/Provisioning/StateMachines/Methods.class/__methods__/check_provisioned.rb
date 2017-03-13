#
# Description: This method checks to see if the stack has been provisioned
#   and whether the refresh has completed
#

def refresh_provider(service)
  provider = service.orchestration_manager

  $evm.log("info", "Refreshing provider #{provider.name}")
  $evm.set_state_var('provider_last_refresh', provider.last_refresh_date.to_i)
  provider.refresh
end

def refresh_may_have_completed?(service)
  stack = service.orchestration_stack
  refreshed_stack = $evm.vmdb(:orchestration_stack).find_by(:name => stack.name, :ems_ref => stack.ems_ref)
  if refreshed_stack
    refreshed_stack.status != 'CREATE_IN_PROGRESS'
  elsif $evm.get_state_var('deploy_result') == 'error' && service.orchestration_stack_status[0] == 'check_status_failed'
    # stack failed and has been removed from the provider, no need to wait for refresh complete
    true
  else
    false
  end
end

def check_deployed(service)
  $evm.log("info", "Check orchestration deployed")
  # check whether the stack deployment completed
  status, reason = service.orchestration_stack_status
  case status.downcase
  when 'create_complete'
    $evm.root['ae_result'] = 'ok'
  when 'rollback_complete', 'delete_complete', /failed$/, /canceled$/
    $evm.root['ae_result'] = 'error'
    $evm.root['ae_reason'] = reason
  else
    # deployment not done yet in provider
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
    return
  end

  $evm.log("info", "Stack deployment finished. Status: #{$evm.root['ae_result']}, reason: #{$evm.root['ae_reason']}")
  $evm.log("info", "Please examine stack resources for more details") if $evm.root['ae_result'] == 'error'

  return unless service.orchestration_stack
  $evm.set_state_var('deploy_result', $evm.root['ae_result'])
  $evm.set_state_var('deploy_reason', $evm.root['ae_reason'])

  refresh_provider(service)

  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '30.seconds'
end

def check_refreshed(service)
  $evm.log("info", "Check refresh status of stack (#{service.stack_name})")

  if refresh_may_have_completed?(service)
    $evm.root['ae_result'] = $evm.get_state_var('deploy_result')
    $evm.root['ae_reason'] = $evm.get_state_var('deploy_reason')
    $evm.log("info", "Refresh completed.")
  else
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '30.seconds'
  end
end

task = $evm.root["service_template_provision_task"]
service = task.destination
if $evm.state_var_exist?('provider_last_refresh')
  check_refreshed(service)
else
  check_deployed(service)
end
task.miq_request.user_message = $evm.root['ae_reason'].truncate(255) unless $evm.root['ae_reason'].blank?

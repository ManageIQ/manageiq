#
# Description: This method checks to see if the stack has been reconfigured
#   and whether the refresh has completed
#

def refresh_provider(service)
  provider = service.orchestration_manager

  $evm.log("info", "Refreshing provider #{provider.name}")
  $evm.set_state_var('provider_last_refresh', provider.last_refresh_date.to_i)
  provider.refresh
end

def refresh_may_have_completed?(service)
  provider = service.orchestration_manager
  provider.last_refresh_date.to_i > $evm.get_state_var('provider_last_refresh')
end

def check_updated(service)
  $evm.log("info", "Check orchestration deployed")
  # check whether the stack update has completed
  status, reason = service.orchestration_stack_status
  case status.downcase
  when 'update_complete'
    $evm.root['ae_result'] = 'ok'
    # update the orchestration_template only upon completion
    service.orchestration_template = service.service_template.orchestration_template
  when /rollback_complete$/
    $evm.root['ae_result'] = 'error'
    $evm.root['ae_reason'] = 'Stack update was rolled back'
  when /failed$/
    $evm.root['ae_result'] = 'error'
    $evm.root['ae_reason'] = reason
  else
    # update not done yet in provider
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
    return
  end

  $evm.log("info", "Stack update finished. Status: #{$evm.root['ae_result']}, reason: #{$evm.root['ae_reason']}")

  $evm.set_state_var('update_result', $evm.root['ae_result'])
  $evm.set_state_var('update_reason', $evm.root['ae_reason'])

  refresh_provider(service)

  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '30.seconds'
end

def check_refreshed(service)
  $evm.log("info", "Check refresh status of stack (#{service.stack_name})")

  if refresh_may_have_completed?(service)
    $evm.root['ae_result'] = $evm.get_state_var('update_result')
    $evm.root['ae_reason'] = $evm.get_state_var('update_reason')
  else
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '30.seconds'
  end
end

task = $evm.root["service_reconfigure_task"]
service = task.source
if $evm.state_var_exist?('provider_last_refresh')
  check_refreshed(service)
else
  check_updated(service)
end
task.miq_request.user_message = $evm.root['ae_reason'] unless $evm.root['ae_reason'].blank?

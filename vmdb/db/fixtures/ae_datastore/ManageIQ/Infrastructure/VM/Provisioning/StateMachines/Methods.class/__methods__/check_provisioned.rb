###################################
#
# EVM Automate Method: check_provisioned
#
# Notes: This method checks to see if the vm has been provisioned
#
###################################
begin
  @method = 'check_provisioned'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  # Get current provisioning status
  task = $evm.root['miq_provision']
  task_status = task['status']
  result = task.status

  $evm.log('info', "#{@method} - ProvisionCheck returned <#{result}> for state <#{task.state}> and status <#{task_status}>") if @debug

  case result
  when 'error'
    $evm.root['ae_result'] = 'error'
    reason = $evm.root['miq_provision'].message
    reason = reason[7..-1] if reason[0..6] == 'Error: '
    $evm.root['ae_reason'] = reason
  when 'retry'
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  when 'ok'
    # Bump State
    $evm.root['ae_result'] = 'ok'
  end

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end

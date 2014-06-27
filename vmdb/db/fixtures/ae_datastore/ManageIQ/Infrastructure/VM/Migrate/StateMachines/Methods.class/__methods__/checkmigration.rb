###################################
#
# EVM Automate Method: CheckMigration
#
# Notes: This method checks to see if the VM has been migrated
#
###################################
begin
  @method = 'CheckMigration'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Get current provisioning status
  result = $evm.root["vm_migrate_task"].status

  $evm.log('info', "#{@method} returned <#{result}>")

  case result
  when 'error'
    $evm.root['ae_result'] = 'error'
    reason = $evm.root['miq_provision'].message
    reason = reason[7..-1] if reason[0..6] == 'Error: '
    $evm.root['ae_reason'] = reason
  when 'retry'
    $evm.root['ae_result']      = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  when 'ok'
    # Bump State
    $evm.root['ae_result'] = 'ok'
  end

  #
  # Exit method
  #
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end

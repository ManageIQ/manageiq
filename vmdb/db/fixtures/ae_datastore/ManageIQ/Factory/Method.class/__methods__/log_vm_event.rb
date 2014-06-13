###################################
#
# EVM Automate Method: log_vm_event
#
# Notes: This method is used to log_vm_events
#
###################################
begin
  @method = 'log_vm_event'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  obj = $evm.object("process")
  $evm.log("info", "VM Discovery for #{obj['name']} State: #{obj['vm_state']} Family: #{obj['vm_os_family']}")

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
  exit MIQ_STOP
end

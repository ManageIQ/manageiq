###################################
#
# EVM Automate Method: vm_migrate_auto_approve
#
# Notes: This method auto-approves the vm migration request
#
#
###################################
begin
  @method = 'vm_migrate_auto_approve'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  # Auto-Approve request
  $evm.log("info", "#{@method} - AUTO-APPROVING") if @debug
  $evm.root["miq_request"].approve("admin", "Auto-Approved")

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

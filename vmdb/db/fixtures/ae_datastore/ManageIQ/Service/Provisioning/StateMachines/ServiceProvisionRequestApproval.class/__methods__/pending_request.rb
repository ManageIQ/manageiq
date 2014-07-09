###################################
#
# EVM Automate Method: pending_request
#
# Notes: This method is executed when the provisioning request is NOT auto-approved
#
###################################
begin
  @method = 'pending_request'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  # Get objects
  provision_request = $evm.root['miq_request'].resource
  msg = $evm.object['reason']
  $evm.log('info', "#{@method} - #{msg}") if @debug

  # execute email method to notify the requester
  # $evm.instantiate("/Alert/EmailNotifications/request_pending?reason=>#{msg}")

  # Raise automation event: request_pending
  $evm.root["miq_request"].pending

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

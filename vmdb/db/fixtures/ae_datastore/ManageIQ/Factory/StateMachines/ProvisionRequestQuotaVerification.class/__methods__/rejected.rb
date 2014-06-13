###################################
#
# EVM Automate Method: rejected
#
# Notes: This method runs when the provision request quota validation has failed
#
###################################
begin
  @method = 'rejected'
  $evm.log("info", "#{@method} - EVM Automate Method: <#{@method}> Started")

  # Deny the request
  $evm.log('info', "Request denied because of Quota")
  $evm.root["miq_request"].deny("admin", "Quota Exceeded")
  # $evm.root["miq_request"].pending("admin", "Quota Exceeded")

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end

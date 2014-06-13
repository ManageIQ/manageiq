###################################
#
# EVM Automate Method: validate_request
#
#
###################################
begin
  @method = 'validate_request'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of debugging
  @debug = true

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

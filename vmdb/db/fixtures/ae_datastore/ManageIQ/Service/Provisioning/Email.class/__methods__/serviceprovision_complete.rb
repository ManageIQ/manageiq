###################################
#
# EVM Automate Method: ServiceProvision_Complete
#
# Notes: Place holder for Service Provision Complete email #
###################################
begin
  @method = 'ServiceProvision_Complete'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
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
  exit MIQ_STOP
end

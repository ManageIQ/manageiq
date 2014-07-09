###################################
#
# EVM Automate Method: PreDeleteFromVC
#
# Notes:This retirement method runs prior to deleting the VM from VC
#
#
###################################
begin
  @method = 'PreDeleteFromProvider'
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
  exit MIQ_ABORT
end

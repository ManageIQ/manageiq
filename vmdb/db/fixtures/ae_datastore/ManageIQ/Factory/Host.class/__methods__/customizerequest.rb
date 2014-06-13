###################################
#
# EVM Automate Method: CustomizeRequest
#
# Notes: This method is used to Customize the provisioning request
#
###################################
begin
  @method = 'CustomizeRequest'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true

  #
  # Initialize variables
  #
  prov   = $evm.root['miq_host_provision']
  $evm.log("info", "Inspecting the provisioning object: <#{prov.inspect}>") if @debug

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

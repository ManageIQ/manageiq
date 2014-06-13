###################################
#
# EVM Automate Method: provision
#
# Notes: This method launches the provisioning job
#
###################################
begin
  @method = 'provision'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  $evm.root["miq_host_provision"].execute

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

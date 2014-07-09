###################################
#
# EVM Automate Method: PostProvision
#
# Notes: This method is used to process tasks immediately after the VM has been provisioned
#
###################################
begin
  @method = 'PostProvision'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  #
  # Get Variables
  #
  prov = $evm.root["miq_provision"]
  $evm.log("info", "#{@method} - Provisioning ID:<#{prov.id}> Provision Request ID:<#{prov.miq_provision_request.id}>") if @debug

  # Get provissioned VM from prov object
  vm = prov.vm
  unless vm.nil?
    $evm.log("info", "#{@method} - VM:<#{vm.name}> has been provisioned") if @debug
  end

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

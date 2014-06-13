###################################
#
# EVM Automate Method: unregister_from_vc
#
# Notes: This method unregisters the VM from the EMS
#
###################################
begin
  @method = 'unregister_from_vc'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  vm = $evm.root['vm']
  unless vm.nil?
    ems = vm.ext_management_system
    $evm.log('info', "#{@method} - Unregistering VM:<#{vm.name}> from EMS:<#{ems ? ems.name : nil}") if @debug
    vm.unregister
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

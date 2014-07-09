###################################
#
# EVM Automate Method: power_off
#
# Notes: This method powers-off the VM on the VC
#
###################################
begin
  @method = 'power_off'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  vm = $evm.root['vm']
  unless vm.nil? || vm.attributes['power_state'] == 'off'
    ems = vm.ext_management_system
    $evm.log('info', "#{@method} - Powering Off VM <#{vm.name}> in VC <#{ems ? ems.name : nil}") if @debug
    vm.stop
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

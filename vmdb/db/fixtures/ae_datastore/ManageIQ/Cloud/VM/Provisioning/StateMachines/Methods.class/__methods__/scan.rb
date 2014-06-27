###################################
#
# EVM Automate Method: scan
#
# Notes: This method performs SmartState analysis on a VM
#
###################################
begin
  @method = 'scan'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  vm = $evm.root['vm']
  unless vm.nil?
    ems = vm.ext_management_system
    $evm.log('info', "#{@method} - Starting Scan of VM <#{vm.name}> in VC <#{ems ? ems.name : nil}") if @debug
    vm.scan
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

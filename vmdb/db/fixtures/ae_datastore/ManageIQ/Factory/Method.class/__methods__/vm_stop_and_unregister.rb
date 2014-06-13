###################################
#
# EVM Automate Method: vm_stop_and_unregister
#
# Notes: This method is used to stop a vm and unregister a vm from the VC
#
###################################
begin
  @method = 'vm_stop_and_unregister'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true

  #
  # Look in the current object for a VM
  #
  vm = $evm.object['vm']
  if vm.nil?
    vm_id = $evm.object['vm_id'].to_i
    vm = $evm.vmdb('vm', vm_id) unless vm_id == 0
  end

  #
  # Look in the Root Object for a VM
  #
  if vm.nil?
    vm = $evm.root['vm']
    if vm.nil?
      vm_id = $evm.root['vm_id'].to_i
      vm = $evm.vmdb('vm', vm_id) unless vm_id == 0
    end
  end

  #
  # No VM Found, exit
  #
  raise "VM not found" if vm.nil?

  $evm.log("info", "VM Tags: #{vm.tags.inspect}") if @debug
  if vm.attributes['power_state'] == "on"
    $evm.log("info", "Stopping VM: [#{vm.attributes['name']}]")
    vm.stop
  end

  $evm.log("info", "Unregistering VM: [#{vm.attributes['name']}]")
  vm.unregister

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

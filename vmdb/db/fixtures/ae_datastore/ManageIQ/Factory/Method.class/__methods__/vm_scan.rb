###################################
#
# EVM Automate Method: vm_scan
#
# Notes: This method is used to launch a Smart State Analysis on a vm
#
###################################
begin
  @method = 'vm_scan'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true

  $evm.log("info", "===========================================")
  $evm.log("info", "Dumping Object")

  $evm.log("info", "Args:    #{MIQ_ARGS.inspect}")

  obj = $evm.object
  $evm.log("info", "Listing Object Attributes:")
  obj.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") } if @debug
  $evm.log("info", "===========================================")

  parent = $evm.object("..")
  profiles = parent.attributes["profiles"]
  $evm.log("info", "scan profiles: #{profiles.inspect}") if @debug

  #
  # Look in the current object for a VM
  #
  vm = $evm.object['vm']
  if vm.nil?
    vm_id = $evm.object['vm_id'].to_i
    vm = $evm.vmdb('vm', vm_id) unless vm_id == 0
  end

  #
  # Look in the parent object for a VM
  #
  if vm.nil?
    vm = parent['vm']
    if vm.nil?
      vm_id = parent['vm_id'].to_i
      vm = $evm.vmdb('vm', vm_id) unless vm_id == 0
    end
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

  $evm.log("info", "VM Attributes")
  vm.attributes.sort.each  { |k, v| $evm.log("info", "\t#{k}: #{v}") } if @debug

  job = vm.scan(profiles)
  $evm.log("info", "Job Attributes")
  job.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") unless k == 'process' } if @debug
  $evm.log("info", "===========================================")

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

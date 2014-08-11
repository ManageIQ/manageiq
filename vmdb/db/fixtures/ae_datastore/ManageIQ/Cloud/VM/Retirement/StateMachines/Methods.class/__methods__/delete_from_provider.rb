###################################
#
# EVM Automate Method: delete_from_provider
#
# Notes: This method deletes the VM from the provider
#
###################################
begin
  @method = 'delete_from_provider'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  # Get vm from root object
  vm = $evm.root['vm']
  category = "lifecycle"
  tag = "retire_full"

  miq_guid = /\w*MIQ\sGUID/i
  if vm.v_annotation =~  miq_guid
    vm_was_provisioned = true
  else
    vm_was_provisioned = false
  end

  if vm && (vm_was_provisioned || vm.miq_provision || vm.tagged_with?(category, tag))
    ems = vm.ext_management_system
    $evm.log('info', "#{@method} - Deleting VM:<#{vm.name}> from EMS:<#{ems ? ems.name : nil}>") if @debug
    vm.remove_from_disk
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

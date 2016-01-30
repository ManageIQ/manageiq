#
# Description: This method removes the VM from the provider
#

# Get vm from root object
vm = $evm.root['vm']

removal_type = $evm.inputs['removal_type'].downcase
$evm.set_state_var('vm_removed_from_provider', false)

if vm
  ems = vm.ext_management_system
  case removal_type
  when "remove_from_disk"
    $evm.log('info', "Removing VM:<#{vm.name}> from provider:<#{ems.try(:name)}>")
    vm.remove_from_disk(false)
    $evm.set_state_var('vm_removed_from_provider', true)
  when "unregister"
    $evm.log('info', "Unregistering VM:<#{vm.name}> from provider:<#{ems.try(:name)}")
    vm.unregister
    $evm.set_state_var('vm_removed_from_provider', true)
  else
    $evm.log('info', "Unknown retirement type for VM:<#{vm.name}> from provider:<#{ems.try(:name)}")
    exit MIQ_ABORT
  end
end

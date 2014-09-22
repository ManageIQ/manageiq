#
# Description: This method deletes the VM from the provider
#

# Get vm from root object
vm = $evm.root['vm']
category = "lifecycle"
tag = "retire_full"

deletion_type = $evm.inputs['deletion_type'].downcase
$evm.set_state_var('vm_deleted_from_provider', false)

if vm
  ems = vm.ext_management_system
  case deletion_type
  when "remove_from_disk"
    if vm.miq_provision || vm.tagged_with?(category, tag)
      $evm.log('info', "Deleting VM:<#{vm.name}> from provider:<#{ems.try(:name)}>")
      vm.remove_from_disk
      $evm.set_state_var('vm_deleted_from_provider', true)
    end
  when "unregister"
    $evm.log('info', "Unregistering VM:<#{vm.name}> from provider:<#{ems.try(:name)}")
    vm.unregister
    $evm.set_state_var('vm_deleted_from_provider', true)
  else
    $evm.log('info', "Unknown retirement type for VM:<#{vm.name}> from provider:<#{ems.try(:name)}")
    exit MIQ_ABORT
  end
end

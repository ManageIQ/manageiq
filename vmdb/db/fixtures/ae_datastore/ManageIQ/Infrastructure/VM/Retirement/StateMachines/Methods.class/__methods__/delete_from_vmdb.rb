#
# Description: This method removes the VM from the VMDB database
#

vm = $evm.root['vm']

if vm && $evm.get_state_var('vm_deleted_from_provider')
  $evm.log('info', "Deleting VM <#{vm.name}> from VMDB")
  vm.remove_from_vmdb
end

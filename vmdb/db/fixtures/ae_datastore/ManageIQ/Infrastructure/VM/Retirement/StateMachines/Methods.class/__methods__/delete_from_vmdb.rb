#
# Description: This method removes the VM from the VMDB database
#

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
  $evm.log('info', "Deleting VM <#{vm.name}> from VMDB")
  vm.remove_from_vmdb
end

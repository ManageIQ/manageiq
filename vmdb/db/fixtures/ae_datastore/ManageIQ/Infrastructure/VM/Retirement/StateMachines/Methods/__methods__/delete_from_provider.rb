#
# Description: This method deletes the VM from the provider
#

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
  $evm.log('info', "Deleting VM:<#{vm.name}> from EMS:<#{ems ? ems.name : nil}>")
  vm.remove_from_disk
end

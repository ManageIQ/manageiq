#
# Description: This method removes the VM from the provider
#

# Get vm from root object
vm = $evm.root['vm']
category = "lifecycle"
tag = "retire_full"

removal_type = $evm.inputs['removal_type'].downcase
$evm.set_state_var('vm_removed_from_provider', false)
ems = vm.ext_management_system if vm

if vm.nil? || ems.nil?
  $evm.log('info', "Skipping remove from provider for VM:<#{vm.try(:name)}> on provider:<#{ems.try(:name)}>")
  exit MIQ_OK
end

case removal_type
when "remove_from_disk"
  if vm.miq_provision || vm.tagged_with?(category, tag)
    $evm.log('info', "Removing VM:<#{vm.name}> from provider:<#{ems.name}>")
    vm.remove_from_disk(false)
    $evm.set_state_var('vm_removed_from_provider', true)
  end
when "unregister"
  $evm.log('info', "Unregistering VM:<#{vm.name}> from provider:<#{ems.name}>")
  vm.unregister
  $evm.set_state_var('vm_removed_from_provider', true)
else
  $evm.log('info', "Unknown retirement type for VM:<#{vm.name}> from provider:<#{ems.name}>")
  exit MIQ_ABORT
end

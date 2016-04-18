#
# Description: This method suspends the Openstack Instance
#

vm = $evm.root['vm']
if vm.nil?
  $evm.log('info', "VM not found, cannot retire.")
  exit MIQ_ABORT
end
ems = vm.ext_management_system
if ems.nil?
  $evm.log('info', "VM:<#{vm.name}> has no provider.")
  exit MIQ_OK
end

if vm.attributes['power_state'] == 'on'
  $evm.log('info', "Suspending Openstack Instance <#{vm.name}> in EMS <#{ems.try(:name)}")
  vm.suspend
end

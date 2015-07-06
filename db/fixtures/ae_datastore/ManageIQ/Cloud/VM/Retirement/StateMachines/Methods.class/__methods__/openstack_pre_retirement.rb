#
# Description: This method suspends the Openstack Instance
#

vm = $evm.root['vm']
unless vm.nil? || vm.attributes['power_state'] == 'off'
  ems = vm.ext_management_system
  $evm.log('info', "Suspending Openstack Instance <#{vm.name}> in EMS <#{ems ? ems.name : nil}")
  vm.suspend if ems
end

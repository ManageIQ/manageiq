#
# Description: This method stops the Azure Instance
#

vm = $evm.root['vm']
if vm && vm.power_state == 'on'
  ems = vm.ext_management_system
  $evm.log('info', "Stopping Azure Instance <#{vm.name}> in EMS <#{ems.try(:name)}>")
  vm.stop if ems
end

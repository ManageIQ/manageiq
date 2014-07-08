#
# Description: This method powers-off the VM on the VC
#

vm = $evm.root['vm']
unless vm.nil? || vm.attributes['power_state'] == 'off'
  ems = vm.ext_management_system
  $evm.log('info', "Powering Off VM <#{vm.name}> in VC <#{ems ? ems.name : nil}")
  vm.stop
end

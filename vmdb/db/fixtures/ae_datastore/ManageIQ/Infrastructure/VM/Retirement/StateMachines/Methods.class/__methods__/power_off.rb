#
# Description: This method powers-off the VM on the provider
#

vm = $evm.root['vm']
unless vm.nil? || vm.attributes['power_state'] == 'off'
  ems = vm.ext_management_system
  $evm.log('info', "Powering Off VM <#{vm.name}> in provider <#{ems.try(:name)}>")
  vm.stop
end

#
# Description: This method unregisters the VM from the provider
#

vm = $evm.root['vm']
unless vm.nil?
  ems = vm.ext_management_system
  $evm.log('info', "Unregistering VM:<#{vm.name}> from EMS:<#{ems ? ems.name : nil}")
  vm.unregister
end

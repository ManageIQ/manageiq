#
# Description: This method performs SmartState analysis on a VM
#

vm = $evm.root['vm']
unless vm.nil?
  ems = vm.ext_management_system
  $evm.log('info', "Starting Scan of VM <#{vm.name}> in VC <#{ems ? ems.name : nil}")
  vm.scan
end

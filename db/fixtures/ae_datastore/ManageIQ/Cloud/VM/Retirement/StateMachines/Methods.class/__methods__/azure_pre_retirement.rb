#
# Description: This method stops the Azure Instance
#

vm = $evm.root['vm']
if vm.nil?
  $evm.log('info', "VM not found, cannot retire.")
  $evm.root['ae_result'] = 'error'
  exit MIQ_ABORT
end
ems = vm.ext_management_system
if ems.nil?
  $evm.log('info', "VM:<#{vm.name}> has no provider.")
  $evm.root['ae_result'] = 'ok'
  exit MIQ_OK
end
if vm.power_state == 'on'
  $evm.log('info', "Stopping Azure Instance <#{vm.name}> in EMS <#{ems.try(:name)}>")
  vm.stop
end

#
# Description: This method stops the Amazon Instance
# If the Instance is not on a EBS store we can skip stopping the instance
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
if vm.attributes['power_state'] == 'on'
  if vm.hardware.root_device_type == "instance_store"
    $evm.log('info', "Stop not required for non EBS Amazon Instance <#{vm.name}> in EMS <#{ems.try(:name)}>")
  else
    $evm.log('info', "Stopping Amazon Instance <#{vm.name}> in EMS <#{ems.try(:name)}>")
    vm.stop
  end
end

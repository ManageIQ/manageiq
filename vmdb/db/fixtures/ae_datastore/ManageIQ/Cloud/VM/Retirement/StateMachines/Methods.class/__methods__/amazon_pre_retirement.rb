#
# Description: This method stops the Amazon Instance
# If the Instance is not on a EBS store we can skip stopping the instance
#

vm = $evm.root['vm']
if vm && vm.attributes['power_state'] == 'on'
  ems = vm.ext_management_system
  if vm.hardware.root_device_type == "ebs"
    $evm.log('info', "Stopping Amazon Instance <#{vm.name}> in EMS <#{ems ? ems.name : nil}>")
    vm.stop if ems
  else
    $evm.log('info', "Skipping stopping of non EBS Amazon Instance <#{vm.name}> in EMS <#{ems ? ems.name : nil}>")
  end
end

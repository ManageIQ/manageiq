#
# Description: This method stops the Amazon Instance
# If the Instance is not on a EBS store we can skip stopping the instance
#

vm = $evm.root['vm']
ems = vm.ext_management_system if vm

if vm.nil? || ems.nil?
  $evm.log('info', "Skipping Amazon pre retirement for Instance:<#{vm.try(:name)}> on EMS:<#{ems.try(:name)}> "\
              "with instance store type <#{vm.hardware.root_device_type}>")
  exit MIQ_OK
end

power_state = vm.power_state
if power_state == "on"
  if vm.hardware.root_device_type.blank?
    $evm.log('error', "Aborting Amazon pre retirement, empty root_device_type."\
                      "  Instance <#{vm.name}> may have been provisioned externally.")
    exit MIQ_ABORT
  end

  if vm.hardware.root_device_type == "ebs"
    $evm.log('info', "Stopping EBS Amazon Instance <#{vm.name}> in EMS <#{ems.name}>")
    vm.stop
  else
    $evm.log('info', "Skipping stopping of non EBS Amazon Instance <#{vm.name}> in EMS <#{ems.name}> "\
              "with instance store type <#{vm.hardware.root_device_type}>")
  end
end

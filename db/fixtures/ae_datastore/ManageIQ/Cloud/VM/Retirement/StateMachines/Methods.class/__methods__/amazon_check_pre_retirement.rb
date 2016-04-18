#
# Description: This method checks to see if the amazon instance has been powered off
# if the instance is on a instance store we cannot stop it
#

# Get vm from root object
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
power_state = vm.attributes['power_state']

$evm.log('info', "Instance: <#{vm.name}> on EMS: <#{ems.try(:name)} has Power State: <#{power_state}>")
if power_state == "never"
  # If never then this VM is a template so exit the retirement state machine
  $evm.root['ae_result'] = 'error'
  exit MIQ_ABORT
end
# If VM is powered off or this instance is running on an instance store
if %w(off suspended terminated).include?(power_state) || vm.hardware.root_device_type == "instance_store"
  # Bump State
  $evm.root['ae_result'] = 'ok'
else
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = '60.seconds'
end

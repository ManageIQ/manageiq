#
# Description: This method checks to see if the instance has been powered off or suspended
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
power_state = vm.power_state
$evm.log('info', "Instance: <#{vm.name}> on EMS: <#{ems.try(:name)} has Power State: <#{power_state}>")

if power_state == "never"
  # If never then this VM is a template so exit the retirement state machine
  $evm.log('info', "Power state: <#{power_state}>, cannot retire.")
  $evm.root['ae_result'] = 'error'
  exit MIQ_ABORT
end
# If VM is powered off or suspended exit
if %w(off suspended).include?(power_state)
  # Bump State
  $evm.root['ae_result'] = 'ok'
else
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = '60.seconds'
end

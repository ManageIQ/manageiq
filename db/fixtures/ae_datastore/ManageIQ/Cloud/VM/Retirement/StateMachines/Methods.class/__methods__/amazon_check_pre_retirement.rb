#
# Description: This method checks to see if the amazon instance has been powered off
# if the instance is on a instance store we cannot stop it
#

# Get vm from root object
vm = $evm.root['vm']
ems = vm.ext_management_system if vm

if vm.nil? || ems.nil?
  $evm.log('info', "Skipping check pre retirement for Instance:<#{vm.try(:name)}> on EMS:<#{ems.try(:name)}>")
  exit MIQ_OK
end

power_state = vm.power_state
$evm.log('info', "Instance:<#{vm.name}> on EMS:<#{ems.name}> has Power State:<#{power_state}>")
# If VM is powered off, suspended, terminated, unknown or this instance is running on an instance store exit
if %w(off suspended terminated unknown).include?(power_state) || vm.hardware.root_device_type == "instance-store"
  # Bump State
  $evm.root['ae_result'] = 'ok'
elsif power_state == "never"
  # If never then this VM is a template so exit the retirement state machine
  $evm.root['ae_result'] = 'error'
else
  vm.refresh
  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '60.seconds'
end

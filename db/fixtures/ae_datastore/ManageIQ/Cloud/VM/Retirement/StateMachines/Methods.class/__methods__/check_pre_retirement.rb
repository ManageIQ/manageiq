#
# Description: This method checks to see if the instance has been powered off or suspended
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
# If VM is powered off, suspended or unknown exit
if %w(off suspended unknown).include?(power_state)
  # Bump State
  $evm.root['ae_result'] = 'ok'
elsif power_state == "never"
  # If never then this VM is a template so exit the retirement state machine
  $evm.root['ae_result'] = 'error'
else
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = '60.seconds'
end

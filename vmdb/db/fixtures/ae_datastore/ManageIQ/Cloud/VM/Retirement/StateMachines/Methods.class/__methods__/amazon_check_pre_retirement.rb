#
# Description: This method checks to see if the amazon instance has been powered off
# if the instance is on a instance store we cannot stop it
#

# Get vm from root object
vm = $evm.root['vm']

if vm
  power_state = vm.attributes['power_state']
  ems = vm.ext_management_system
  $evm.log('info', "Instance:<#{vm.name}> on EMS:<#{ems.try(:name)} has Power State:<#{power_state}>")

  # If VM is powered off or this instance is running on an instance store
  if %w(off suspended).include?(power_state) || vm.hardware.root_device_type == "instance_store"
    # Bump State
    $evm.root['ae_result'] = 'ok'
  elsif power_state == "never"
    # If never then this VM is a template so exit the retirement state machine
    $evm.root['ae_result'] = 'error'
  else
    $evm.root['ae_result']	   = 'retry'
    $evm.root['ae_retry_interval'] = '60.seconds'
  end
end

#
# Description: This method checks to see if the VM has been powered off or suspended
#

# Get vm from root object
vm = $evm.root['vm']

unless vm.nil?
  power_state = vm.attributes['power_state']
  ems = vm.ext_management_system
  $evm.log('info', "VM:<#{vm.name}> on EMS:<#{ems ? ems.name : nil} has Power State:<#{power_state}>")

  # If VM is powered off or suspended exit
  if power_state == "off" || power_state == "suspended"
    # Bump State
    $evm.root['ae_result'] = 'ok'
  elsif power_state == "never"
    # If never then this VM is a template so exit the retirement state machine
    $evm.root['ae_result'] = 'error'
  else
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '15.seconds'
  end
end

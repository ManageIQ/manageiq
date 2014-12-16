#
# Description: This method is a placeholder for updating the retirement status
# Required inputs: status
#

# Get variables from Server object
server = $evm.root['miq_server']

# Get State Machine
state = $evm.current_object.class_name

# Get current step
step = $evm.current_object.current_field_name

# Get status from input field status
status = $evm.inputs['status']

# Get status_state ['on_entry', 'on_exit', 'on_error']
status_state = $evm.root['ae_status_state']

$evm.log("info", "Server:<#{server.name}> Ae_Result:<#{$evm.root['ae_result']}> State:<#{state}> Step:<#{step}> Status_State:<#{status_state}> Status:<#{status}>")

# Update Status for on_entry,on_exit
if $evm.root['ae_result'] == 'ok'
end

# Update Status for on_error
if $evm.root['ae_result'] == 'error'
  if step.downcase == 'startretirement'
     $evm.log("info", "Cannot continue because VM is already retired or is being retired.")
  else
     vm.retirement_state = 'error'
  end
end

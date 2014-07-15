#
# Description: This method is a placeholder for retirement status update
#

# Get variables from Server object
server = $evm.root['miq_server']

# Get State Machine
state = $evm.current_object.class_name

# Get current step
step = $evm.current_object.current_field_name

# Get status from input field status
status = $evm.inputs['status']

# Get status_state ['on_entry', 'on_exit', 'on_error'] from input field
status_state = $evm.inputs['status_state']

$evm.log("info", "Server:<#{server.name}> Ae_Result:<#{$evm.root['ae_result']}> State:<#{state}> Step:<#{step}> Status_State:<#{status_state}> Status:<#{status}>")

if $evm.root['ae_result'] == 'ok'
end

if $evm.root['ae_result'] == 'error'
end

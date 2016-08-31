#
# Description: This method updates retirement status
#

# Get variables from Server object
server = $evm.root['miq_server']

# Get State Machine
state  = $evm.current_object.class_name
status = $evm.inputs['status']

# Get current step
step = $evm.current_object.current_field_name

# Get status_state ['on_entry', 'on_exit', 'on_error']
status_state = $evm.root['ae_status_state']

$evm.log("info", "Server:<#{server.name}> Ae_Result:<#{$evm.root['ae_result']}> State:<#{state}>")
$evm.log("info", "Step:<#{step}> Status_State:<#{status_state}> Status:<#{status}>")

load_balancer = $evm.root['load_balancer']

# Update Status for on_error for all states other than the first state which is startretirement
# in the retirement state machine.
if $evm.root['ae_result'] == 'error'
  if step.downcase == 'startretirement'
    $evm.log("info", "Cannot continue because load_balancer is already retired or is being retired.")
  else
    load_balancer.retirement_state = 'error' if load_balancer
  end
end

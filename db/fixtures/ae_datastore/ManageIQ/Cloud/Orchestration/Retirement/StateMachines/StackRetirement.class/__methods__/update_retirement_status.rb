#
# Description: This method updates the stack retirement status.
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

stack = $evm.root['orchestration_stack']

# Update Status Message
updated_message  = "Server [#{server.name}] "
updated_message += "Stack [#{stack.name}] " if stack
updated_message += "Step [#{step}] "
updated_message += "Status [#{status}] "
updated_message += "Current Retry Number [#{$evm.root['ae_state_retries']}]" if $evm.root['ae_result'] == 'retry'

# Update Status for on_error for all states other than the first state which is startretirement
# in the retirement state machine.
if $evm.root['ae_result'] == 'error'
  if step.downcase == 'startretirement'
    msg = "Cannot continue because VM is already retired or is being retired."
    $evm.log("info", msg)
    updated_message += msg
    $evm.create_notification(:level => "warning", :message => "VM Retirement Warning: #{updated_message}")
  else
    $evm.create_notification(:level => "error", :message => "Stack Retirement Error: #{updated_message}")
    stack.retirement_state = 'error' if stack
  end
end

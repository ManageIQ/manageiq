#
# Description: This method updates the vm retirement status.
# Required inputs: status
#

# Get variables from Server object
server = $evm.root['miq_server']

# Get State Machine
state = $evm.current_object.class_name

# Get current step
step = $evm.root['ae_state']

# Get status from input field status
status = $evm.inputs['status']

# Get status_state ['on_entry', 'on_exit', 'on_error']
status_state = $evm.root['ae_status_state']

vm = $evm.root['vm']

$evm.log("info", "Server:<#{server.name}> Ae_Result:<#{$evm.root['ae_result']}> State:<#{state}> Step:<#{step}>")
$evm.log("info", "Status_State:<#{status_state}> Status:<#{status}>")

# Update Status Message
updated_message  = "Server [#{server.name}] "
updated_message += "VM [#{vm.name}] " if vm
updated_message += "Step [#{step}] "
updated_message += "Status [#{status}] "
updated_message += "Current Retry Number [#{$evm.root['ae_state_retries']}]" if $evm.root['ae_result'] == 'retry'

# Update Status for on_error for all states other than the first state which is startretirement
# in the retirement state machine.
if $evm.root['ae_result'] == 'error'
  if step.downcase == 'startretirement'
    msg = "Cannot continue because VM is "
    msg += vm ? "#{vm.retirement_state}." : "nil."
    $evm.log("info", msg)
    updated_message += msg
    $evm.create_notification(:level => "warning", :message => "VM Retirement Warning: #{updated_message}")
  else
    $evm.create_notification(:level => "error", :message => "VM Retirement Error: #{updated_message}")
    vm.retirement_state = 'error' if vm
  end
end

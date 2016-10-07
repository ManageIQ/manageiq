#
# Description: This method updates the service provision status.
# Required inputs: status
#

prov = $evm.root['service_template_provision_task']

unless prov
  $evm.log(:error, "service_template_provision_task object not provided")
  exit(MIQ_STOP)
end

# Get status from input field status
status = $evm.inputs['status']

# Update Status Message
updated_message  = "Server [#{$evm.root['miq_server'].name}] "
updated_message += "Service [#{prov.destination.name}] "
updated_message += "Step [#{$evm.root['ae_state']}] "
updated_message += "Status [#{status}] "
updated_message += "Message [#{prov.message}] "
updated_message += "Current Retry Number [#{$evm.root['ae_state_retries']}]" if $evm.root['ae_result'] == 'retry'
prov.miq_request.user_message = updated_message
prov.message = status

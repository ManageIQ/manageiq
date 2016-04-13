#
# Description: This method updates the service provisioning status
# Required inputs: status
#

prov = $evm.root['service_template_provision_task']

unless prov
  $evm.log(:error, "Service Template Provision Task not provided")
  exit(MIQ_STOP)
end

# Get status from input field status
status = $evm.inputs['status']

# Update Status for on_entry,on_exit
if $evm.root['ae_result'] == 'ok' || $evm.root['ae_result'] == 'error'
  prov.message = status
end

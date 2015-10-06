#
# Description: This method updates the service reconfiguration status
# Required inputs: status
#

prov = $evm.root['service_reconfigure_task']

# Get status from input field status
status = $evm.inputs['status']

# Update Status for on_entry,on_exit
if $evm.root['ae_result'] == 'ok' || $evm.root['ae_result'] == 'error'
  prov.message = status
end

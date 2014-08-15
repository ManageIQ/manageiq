# Description: This method updates the host provisioning status
# Required inputs: status
#

prov   = $evm.root['miq_host_provision']
status = $evm.inputs['status']

# Update Status for on_entry,on_exit
if $evm.root['ae_result'] == 'ok' || $evm.root['ae_result'] == 'error'
  prov.message = status
end

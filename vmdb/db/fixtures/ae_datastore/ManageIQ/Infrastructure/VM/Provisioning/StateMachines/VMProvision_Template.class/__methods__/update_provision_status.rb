#
# Description: This method upates the provision status.
# Required inputs: status
#

prov   = $evm.root['miq_provision']
status = $evm.inputs['status']

# Update Status for on_entry,on_exit
if $evm.root['ae_result'] == 'ok'
  if status == 'provision_complete'
    message = 'VM Provisioned Successfully'
    prov.finished(message)
  end
  prov.message = status
end

# Update Status for on_error
prov.message = status if $evm.root['ae_result'] == 'error'

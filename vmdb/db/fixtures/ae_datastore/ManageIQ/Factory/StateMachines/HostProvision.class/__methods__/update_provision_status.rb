###################################
#
# EVM Automate Method: update_provision_status
#
# Required inputs: status
#
###################################
prov   = $evm.root['miq_host_provision']
status = $evm.inputs['status']

# Update Status for on_entry,on_exit
if $evm.root['ae_result'] == 'ok'
  if status == 'provision_complete'
    message = 'Host Provisioned Successfully'
    prov.finished(message)
  end
  prov.message = status
end

# Update Status for on_error
prov.message = status if $evm.root['ae_result'] == 'error'

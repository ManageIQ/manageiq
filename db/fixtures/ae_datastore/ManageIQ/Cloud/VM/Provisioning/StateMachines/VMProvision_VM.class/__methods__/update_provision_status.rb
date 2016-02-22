#
# Description: Update provision status.
# Required inputs: status
#

prov   = $evm.root['miq_provision']
unless prov
  $evm.log(:error, "miq_provision object not provided")
  exit(MIQ_STOP)
end
status = $evm.inputs['status']

# Update Status for on_entry,on_exit
if $evm.root['ae_result'] == 'ok' || $evm.root['ae_result'] == 'error'
  prov.message = status
end

#
# Description: This method checks to see if the vm has been provisioned
#

# Get provision object
prov = $evm.root['miq_provision'] || $evm.root['miq_host_provision']

# Get current provisioning status
result = prov.status

$evm.log('info', "ProvisionCheck returned <#{result}>")

case result
when 'error'
  $evm.root['ae_result'] = 'error'
  reason = prov.message
  reason = reason[7..-1] if reason[0..6] == 'Error: '
  $evm.root['ae_reason'] = reason
when 'retry'
  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '1.minute'
when 'ok'
  # Bump State
  $evm.root['ae_result'] = 'ok'
end

#
# Description: This method checks to see if the VM has been migrated
#

# Get current provisioning status
result = $evm.root["vm_migrate_task"].status

$evm.log('info', "returned <#{result}>")

case result
when 'error'
  $evm.root['ae_result'] = 'error'
  reason = $evm.root['miq_provision'].message
  reason = reason[7..-1] if reason[0..6] == 'Error: '
  $evm.root['ae_reason'] = reason
when 'retry'
  $evm.root['ae_result']      = 'retry'
  $evm.root['ae_retry_interval'] = '1.minute'
when 'ok'
  # Bump State
  $evm.root['ae_result'] = 'ok'
end

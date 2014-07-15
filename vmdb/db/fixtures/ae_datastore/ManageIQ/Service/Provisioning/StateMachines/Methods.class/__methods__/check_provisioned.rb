#
# Description: This method checks to see if the service has been provisioned
#

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

# Get current provisioning status
task = $evm.root['service_template_provision_task']
task_status = task['status']
result = task.status

$evm.log('info', "Service ProvisionCheck returned <#{result}> for state <#{task.state}> and status <#{task_status}>")

case result
when 'error'
  $evm.root['ae_result'] = 'error'
  reason = $evm.root['service_template_provision_task'].message
  reason = reason[7..-1] if reason[0..6] == 'Error: '
  $evm.root['ae_reason'] = reason
when 'retry'
  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '1.minute'
when 'ok'
  # Bump State
  $evm.root['ae_result'] = 'ok'
end

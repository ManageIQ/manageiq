#
# Description: This method is for services to enforce provision priority
#

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}")}
$evm.log("info", "===========================================")

# Get current provisioning status
task = $evm.root['service_template_provision_task']

# check if the task is in a runnable state, otherwise abort processing
unless task.attributes['status'] == 'Ok'
  $evm.log('info', "Aborting due to task status: <#{task.status}>  task real status: <#{task.attributes['status']}> for Task: <#{task.id}> Description: <#{task.description}> state: <#{task.state}>.")
  exit MIQ_ABORT
end

result = task.group_sequence_run_now?
$evm.log('info', "group_sequence_run_now returned: <#{result}> for Task: <#{task.id}> Description: <#{task.description}> state: <#{task.state}> ")

case result
when false
  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '1.minute'
  $evm.log('info', "Service GroupSequenceCheck determined that it cannot run yet. Setting retry for task id: <#{task.id}> description: <#{task.description}> Parent task: <#{task.miq_request_id}> Parent description: <#{task.miq_request.description}> ")
when true
  # Bump State
  $evm.root['ae_result'] = 'ok'
  $evm.log('info', "Service GroupSequenceCheck determined that it can run. Proceeding with task id: <#{task.id}> description: <#{task.description}>  Parent task: <#{task.miq_request_id}> Parent description: <#{task.miq_request.description}> ")
end

#
# Description: This method launches the orchestration reconfiguration job
#

$evm.log("info", "Starting Orchestration Reconfiguration")

task = $evm.root["service_reconfigure_task"]
service = task.source

begin
  service.update_orchestration_stack
  $evm.log("info", "Stack #{service.stack_name} with reference id (#{service.orchestration_stack.try(:ems_ref)}) is being updated")
rescue => err
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = err.message
  task.miq_request.user_message = err.message.truncate(255)
  $evm.log("error", "Stack #{service.stack_name} update failed. Reason: #{err.message}")
end

#
# Description: This method launches the orchestration provisioning job
#

$evm.log("info", "Starting Orchestration Provisioning")

task = $evm.root["service_template_provision_task"]
service = task.destination

begin
  stack = service.deploy_orchestration_stack
  $evm.log("info", "Stack #{service.stack_name} with reference id (#{stack.ems_ref}) is being created")
rescue => err
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = err.message
  $evm.log("error", "Stack #{service.stack_name} creation failed. Reason: #{err.message}")
end

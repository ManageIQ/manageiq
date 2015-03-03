#
# Description: This method launches the orchestration provisioning job
#

$evm.log("info", "Starting Orchestration Provisioning")

service = $evm.root["service_template_provision_task"].destination

begin
  service.deploy_orchestration_stack
rescue => err
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = err.message
end

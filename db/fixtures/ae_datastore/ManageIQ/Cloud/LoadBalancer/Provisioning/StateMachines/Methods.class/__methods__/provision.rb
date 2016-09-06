#
# Description: This method launches the load_balancer provisioning job
#

$evm.log("info", "Starting LoadBalancer Provisioning")

task = $evm.root["service_template_provision_task"]
service = task.destination

begin
  load_balancer = service.deploy_load_balancer
  $evm.log("info", "LoadBalancer #{service.load_balancer_name} with reference id (#{load_balancer.ems_ref}) is being created")
rescue => err
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = err.message
  task.miq_request.user_message = err.message.truncate(255)
  $evm.log("error", "LoadBalancer #{service.load_balancer_name} creation failed. Reason: #{err.message}")
end

#
# Description: This method launches the load_balancer reconfiguration job
#

$evm.log("info", "Starting LoadBalancer Reconfiguration")

task = $evm.root["service_reconfigure_task"]
service = task.source

begin
  service.update_load_balancer
  $evm.log("info", "LoadBalancer #{service.load_balancer_name} with reference id (#{service.load_balancer.try(:ems_ref)}) is being updated")
rescue => err
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = err.message
  task.miq_request.user_message = err.message.truncate(255)
  $evm.log("error", "LoadBalancer #{service.load_balancer_name} update failed. Reason: #{err.message}")
end

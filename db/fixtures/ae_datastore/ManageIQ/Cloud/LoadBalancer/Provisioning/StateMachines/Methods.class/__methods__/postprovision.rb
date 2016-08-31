#
# Description: This method examines the load_balancer load_balancer provisioned
#
$evm.log("info", "Starting LoadBalancer Post-Provisioning")

task = $evm.root["service_template_provision_task"]
service = task.destination
_load_balancer = service.load_balancer

service.post_provision_configure

#
# Description: This method examines the load_balancer load_balancer reconfigured
#
$evm.log("info", "Starting LoadBalancer Post-Reconfiguration")

service = $evm.root["service_reconfigure_task"].source
_load_balancer = service.load_balancer

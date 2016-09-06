#
# Description: This method prepares arguments and parameters for load_balancer provisioning
#

$evm.log("info", "Starting LoadBalancer Pre-Provisioning")

service = $evm.root["service_template_provision_task"].destination

# Through service you can examine the load_balancer template, manager (i.e., provider)
# load_balancer_name, and options to create the load_balancer
# You can also override these selections through service

$evm.log("info", "manager = #{service.load_balancer_manager.name}(#{service.load_balancer_manager.id})")
$evm.log("info", "load_balancer name = #{service.load_balancer_name}")
$evm.log("info", "load_balancer options = #{service.load_balancer_options.inspect}")

# Example how to programmatically modify load_balancer options:
# service.load_balancer_name = 'new_name'
# load_balancer_options = service.load_balancer_options
# load_balancer_options[:dialog][:dialog_cloud_subnets] = ['subnet-16c70477'],
# # Important: set load_balancer_options
# service.load_balancer_options = load_balancer_options

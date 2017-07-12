#
# Description: This method prepares arguments and parameters for load_balancer reconfiguration
#

$evm.log("info", "Starting LoadBalancer Pre-Reconfiguration")

task = $evm.root["service_reconfigure_task"]
service = task.source
unless service.load_balancer
  err = 'Service contains no load_balancer load_balancer'
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = err
  task.miq_request.user_message = err
  $evm.log("error", "LoadBalancer #{service.load_balancer_name} update failed. Reason: #{err}")
  return
end

# Through service you can examine the load_balancer template, manager (i.e., provider)
# load_balancer_name, and options to update the load_balancer

# The service_template's load_balancer_template will be used to update the load_balancer.
# If another load_balancer_template needs to be used here, it should be set through service.service_template
$evm.log("info", "manager = #{service.load_balancer_manager.name}(#{service.load_balancer_manager.id})")
$evm.log("info", "load_balancer name = #{service.load_balancer_name}")

# Parse the dialog options and convert to options required to update the load_balancer
update_options = service.build_load_balancer_options_from_dialog(task.options[:dialog])
$evm.log("info", "load_balancer update options = #{update_options.inspect}")

# Example how to programmatically modify load_balancer update options:
# update_options[:cloud_subnets] = ['subnet-16c70477'],

# Important: set update_options
service.update_options = update_options

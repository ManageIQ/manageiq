#
# Description: This method prepares arguments and parameters for orchestration provisioning
#

$evm.log("info", "Starting Orchestration Pre-Provisioning")

service = $evm.root["service_template_provision_task"].destination

# Through service you can examine the orchestration template, manager (i.e., provider)
# stack_name, and options to create the stack
# You can also override these selections through service

$evm.log("info", "manager = #{service.orchestration_manager.name}(#{service.orchestration_manager.id})")
$evm.log("info", "template = #{service.orchestration_template.name}(#{service.orchestration_template.id}))")
$evm.log("info", "stack name = #{service.stack_name}")
# Caution: stack_options may contain passwords.
# $evm.log("info", "stack options = #{service.stack_options.inspect}")

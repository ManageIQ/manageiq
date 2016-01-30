#
# Description: This method prepares arguments and parameters for orchestration reconfiguration
#

$evm.log("info", "Starting Orchestration Pre-Reconfiguration")

task = $evm.root["service_reconfigure_task"]
service = task.source
unless service.orchestration_stack
  err = 'Service contains no orchestration stack'
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = err
  task.miq_request.user_message = err
  $evm.log("error", "Stack #{service.stack_name} update failed. Reason: #{err}")
  return
end

# Through service you can examine the orchestration template, manager (i.e., provider)
# stack_name, and options to update the stack

# The service_template's orchestration_template will be used to update the stack.
# If another orchestration_template needs to be used here, it should be set through service.service_template
$evm.log("info", "manager = #{service.orchestration_manager.name}(#{service.orchestration_manager.id})")
$evm.log("info", "template = #{service.service_template.orchestration_template.name}(#{service.service_template.orchestration_template.id}))")
$evm.log("info", "stack name = #{service.stack_name}")

# Parse the dialog options and convert to options required to update the stack
update_options = service.build_stack_options_from_dialog(task.options[:dialog])

# Caution: dialog_options may contain passwords.
# $evm.log("info", "stack update options = #{update_options.inspect}")

# Example how to programmatically modify stack update options:
# update_options[:parameters]['flavor'] = 'm1.small'

# Important: set update_options
service.update_options = update_options

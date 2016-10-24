#
# Description: This method examines the orchestration stack provisioned
#
def dump_stack_outputs(stack)
  $evm.log("info", "Outputs from stack #{stack.name}")
  stack.outputs.each do |output|
    $evm.log("info", "Key #{output.key}, value #{output.value}")
  end
end

$evm.log("info", "Starting Orchestration Post-Provisioning")

task = $evm.root["service_template_provision_task"]
service = task.destination
stack = service.orchestration_stack

service.post_provision_configure

# You can add logic to process the stack object in VMDB
# For example, dump all outputs from the stack
#
# dump_stack_outputs(stack)

$evm.root['ae_result'] = $evm.get_state_var('deploy_result')
$evm.root['ae_reason'] = $evm.get_state_var('deploy_reason')

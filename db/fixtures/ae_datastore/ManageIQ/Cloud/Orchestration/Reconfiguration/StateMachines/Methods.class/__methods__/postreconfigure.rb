#
# Description: This method examines the orchestration stack reconfigured
#
def dump_stack_outputs(stack)
  $evm.log("info", "Outputs from updated stack #{stack.name}")
  stack.outputs.each do |output|
    $evm.log("info", "Key #{output.key}, value #{output.value}")
  end
end

$evm.log("info", "Starting Orchestration Post-Reconfiguration")

service = $evm.root["service_reconfigure_task"].source
stack = service.orchestration_stack

# You can add logic to process the stack object in VMDB
# For example, dump all outputs from the stack
#
# dump_stack_outputs(stack)

#
# Description: This method sets the retirement_state to retiring
#

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

stack = $evm.root['orchestration_stack']
if stack.nil?
  $evm.log('error', "OrchestrationStack Object not found")
  exit MIQ_ABORT
end

if stack.retired?
  $evm.log('error', "Stack is already retired. Aborting current State Machine.")
  exit MIQ_ABORT
end

if stack.retiring?
  $evm.log('error', "Stack is in the process of being retired. Aborting current State Machine.")
  exit MIQ_ABORT
end

$evm.log('info', "Stack before start_retirement: #{stack.inspect} ")
$evm.create_notification(:type => :vm_retiring, :subject => stack)

stack.start_retirement

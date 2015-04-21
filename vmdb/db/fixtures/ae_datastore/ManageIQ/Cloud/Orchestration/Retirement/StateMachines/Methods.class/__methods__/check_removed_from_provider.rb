#
# Description: This method checks to see if the stack has been removed from the provider
#
$evm.root['ae_result'] = 'ok'
stack = $evm.root['orchestration_stack']
$evm.log("info", "Check stack #{stack.name} removed from provider")

if stack
  status, _reason = stack.raw_status
  if status.nil?
    $evm.root['ae_result'] = 'error'
    $evm.root['ae_reason'] = 'Cannot find status of stack #{stack.name}. It may not exist in the provider'
  elsif status.downcase == 'delete_complete'
    $evm.set_state_var('stack_removed_from_provider', true)
  else
    $evm.root['ae_result']	   = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  end
end

#
# Description: This method checks to see if the stack has been removed from the provider
#
$evm.root['ae_result'] = 'ok'
stack = $evm.root['orchestration_stack']
$evm.log("info", "Checking stack #{stack.try(:name)} removed from provider")

if stack && $evm.get_state_var('stack_exists_in_provider')
  status, _reason = stack.raw_status
  if status.nil?
    $evm.root['ae_result'] = 'error'
    $evm.root['ae_reason'] = 'Cannot find status of stack #{stack.name}. It may no longer exist in the provider'
  elsif status.downcase == 'delete_complete'
    $evm.set_state_var('stack_exists_in_provider', false)
  else
    $evm.root['ae_result']	   = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  end
end

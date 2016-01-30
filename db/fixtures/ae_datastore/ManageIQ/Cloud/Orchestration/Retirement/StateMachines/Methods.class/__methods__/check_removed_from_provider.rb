#
# Description: This method checks to see if the stack has been removed from the provider
#
$evm.root['ae_result'] = 'ok'
stack = $evm.root['orchestration_stack']
$evm.log("info", "Checking stack #{stack.try(:name)} removed from provider")

if stack && $evm.get_state_var('stack_exists_in_provider')
  begin
    status, _reason = stack.normalized_live_status
    if status == 'not_exist' || status == 'delete_complete'
      $evm.set_state_var('stack_exists_in_provider', false)
    else
      $evm.root['ae_result'] = 'retry'
      $evm.root['ae_retry_interval'] = '1.minute'
    end
  rescue => e
    $evm.root['ae_result'] = 'error'
    $evm.root['ae_reason'] = e.message
  end
end

#
# Description: This method checks to see if the load_balancer has been removed from the provider
#
begin
  $evm.root['ae_result'] = 'ok'
  load_balancer = $evm.root['load_balancer']
  $evm.log("info", "Checking load_balancer #{load_balancer.try(:name)} removed from provider")

  if load_balancer && $evm.get_state_var('load_balancer_exists_in_provider')
    status, _reason = load_balancer.normalized_live_status
    if status == 'not_exist'
      $evm.set_state_var('load_balancer_exists_in_provider', false)
    else
      $evm.root['ae_result'] = 'retry'
      $evm.root['ae_retry_interval'] = '1.minute'
    end
  end
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end

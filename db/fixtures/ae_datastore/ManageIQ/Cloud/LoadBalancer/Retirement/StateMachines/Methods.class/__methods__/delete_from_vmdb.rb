#
# Description: This method removes the load_balancer from the VMDB database
#
begin
  load_balancer = $evm.root['load_balancer']

  if load_balancer && !$evm.get_state_var('load_balancer_exists_in_provider')
    $evm.log('info', "Removing load_balancer <#{load_balancer.name}> from VMDB")
    load_balancer.remove_from_vmdb
    $evm.root['load_balancer'] = nil
  end
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end

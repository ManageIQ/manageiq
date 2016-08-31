#
# Description: This method removes the load_balancer from the provider
#
begin
  # Get load_balancer from root object
  load_balancer = $evm.root['load_balancer']

  if load_balancer
    ems = load_balancer.ext_management_system
    if load_balancer.raw_exists?
      $evm.log('info', "Removing load_balancer:<#{load_balancer.name}> from provider:<#{ems.try(:name)}>")
      load_balancer.raw_delete_load_balancer
      $evm.set_state_var('load_balancer_exists_in_provider', true)
    else
      $evm.log('info', "LoadBalancer <#{load_balancer.name}> no longer exists in provider:<#{ems.try(:name)}>")
      $evm.set_state_var('load_balancer_existes_in_provider', false)
    end
  end
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end

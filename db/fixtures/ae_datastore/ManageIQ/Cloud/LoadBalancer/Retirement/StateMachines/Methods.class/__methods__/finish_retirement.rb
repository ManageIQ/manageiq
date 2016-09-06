#
# Description: This method marks the load_balancer as retired
#
begin
  load_balancer = $evm.root['load_balancer']
  load_balancer.finish_retirement if load_balancer
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end

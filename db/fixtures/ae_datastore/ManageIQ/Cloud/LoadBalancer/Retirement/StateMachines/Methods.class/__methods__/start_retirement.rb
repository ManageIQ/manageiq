#
# Description: This method sets the retirement_state to retiring
#
begin
  $evm.log("info", "Listing Root Object Attributes:")
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================")

  load_balancer = $evm.root['load_balancer']
  if load_balancer.nil?
    $evm.log('error', "LoadBalancer Object not found")
    exit MIQ_ABORT
  end

  if load_balancer.retired?
    $evm.log('error', "LoadBalancer is already retired. Aborting current State Machine.")
    exit MIQ_ABORT
  end

  if load_balancer.retiring?
    $evm.log('error', "LoadBalancer is in the process of being retired. Aborting current State Machine.")
    exit MIQ_ABORT
  end

  $evm.log('info', "LoadBalancer before start_retirement: #{load_balancer.inspect} ")

  load_balancer.start_retirement

  $evm.log('info', "LoadBalancer after start_retirement: #{load_balancer.reload.inspect} ")
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end

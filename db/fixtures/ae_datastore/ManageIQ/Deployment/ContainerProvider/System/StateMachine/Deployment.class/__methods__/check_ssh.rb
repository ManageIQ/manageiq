def check_ssh
  $evm.log(:info, "**************** #{$evm.root['ae_state']} ****************")
  $evm.log(:info, "tyring to ssh to: #{$evm.root['deployment_master']}")
  $evm.root['container_deployment'] ||= $evm.vmdb(:container_deployment).find(
    $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id]
  )
  $evm.root['container_deployment'].check_connection
  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "#{$evm.root['ae_state']} was finished successfully"
end

begin
  check_ssh
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end

def pre_validate
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")

  # TODO: add openshift ansible inventory pre-validation once available

  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "successful resources pre validation"
  $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} | Message: #{$evm.root['automation_task'].message}")
end

begin
  pre_validate
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end

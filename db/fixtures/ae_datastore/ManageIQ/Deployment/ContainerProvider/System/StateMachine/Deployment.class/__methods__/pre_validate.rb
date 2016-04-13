def pre_validate
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")

  # TODO: add openshift ansible inventory pre-validation once available

  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "successful resources pre validation"
  $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
           "| Message: #{$evm.root['automation_task'].message}")
end

pre_validate

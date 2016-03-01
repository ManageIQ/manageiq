def pre_validate
  $evm.log(:info, "********************** resources pre validation ***************************")
  $evm.root['state'] = "pre_validation"

  # TODO: add openshift ansible inventory pre-validation once available

  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "successful resources pre validation"
end

pre_validate
$evm.log(:info, "State: #{$evm.root['state']} | Result: #{$evm.root['ae_result']} "\
         "| Message: #{$evm.root['automation_task'].message}")
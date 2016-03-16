def cleanup
  $evm.log(:info, "********************** clean_up ***************************")

  $evm.root['state'] = "clean_up"
  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "successful deployment cleanup"
end

cleanup
$evm.log(:info, "State: #{$evm.root['state']} | Result: #{$evm.root['ae_result']} "\
         "| Message: #{$evm.root['automation_task'].message}")
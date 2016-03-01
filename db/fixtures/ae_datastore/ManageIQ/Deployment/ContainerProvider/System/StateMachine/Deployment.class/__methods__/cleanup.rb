def cleanup
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")

  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "successful deployment cleanup"
  $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
           "| Message: #{$evm.root['automation_task'].message}")
end

cleanup

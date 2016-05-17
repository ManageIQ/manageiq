def analyze_deployment
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
  if $evm.root['deployment_method'] == "provision"
    $evm.root['ae_next_state'] = "provision"
  else
    $evm.root['ae_next_state'] = "check_ssh"
    $evm.root['masters'] = $evm.root['automation_task'].automation_request.options[:attrs][:masters]
    $evm.root['nodes'] = $evm.root['automation_task'].automation_request.options[:attrs][:nodes]
    $evm.root['deployment_master'] =  $evm.root['automation_task'].automation_request.options[:attrs][:deployment_master]
    $evm.root['ssh_private_key'] = $evm.root['automation_task'].automation_request.options[:attrs][:ssh_private_key]

  end
  $evm.root['ssh_username'] =  $evm.root['automation_task'].automation_request.options[:attrs][:ssh_username]

  deployment = $evm.vmdb(:container_deployment).find(
      $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id])
  deployment.add_automation_task($evm.root['automation_task'])
  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "deployment type - #{$evm.root['deployment_method']}"
  $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
           "| Message: #{$evm.root['automation_task'].message}")
end

analyze_deployment

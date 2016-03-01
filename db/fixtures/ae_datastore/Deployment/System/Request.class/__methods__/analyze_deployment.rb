def analyze_deployment
  $evm.root['state'] = "analyze_deployment"
  $evm.log(:info, "********************** analyze deployment ***************************")
  $evm.root['deployment_type'] = $evm.root['automation_task'].automation_request.options[:attrs][:deployment_type]

  if $evm.root['deployment_type'] == "managed_provision"
    $evm.root['ae_next_state'] = "provision"
  else
    $evm.root['ae_next_state'] = "check_ssh"
    $evm.root['deployment_master'] = $evm.root['automation_task'].automation_request.options[:attrs][:deployment_master]
    $evm.root['masters'] = $evm.root['automation_task'].automation_request.options[:attrs][:masters]
    $evm.root['nodes'] = $evm.root['automation_task'].automation_request.options[:attrs][:nodes]
  end

  $evm.root['user'] = $evm.root['automation_task'].automation_request.options[:attrs][:username]
  $evm.root['password'] = $evm.root['automation_task'].automation_request.options[:attrs][:password]
  $evm.root['ssh_key_path'] = $evm.root['automation_task'].automation_request.options[:attrs][:ssh_key_path]
  $evm.root['provider_name'] = $evm.root['automation_task'].automation_request.options[:attrs][:provider_name]

  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "deployment type - #{$evm.root['deployment_type']}"
  $evm.log(:info, "State: #{$evm.root['state']} | Result: #{$evm.root['ae_result']} "\
           "| Message: #{$evm.root['automation_task'].message}")
end

analyze_deployment
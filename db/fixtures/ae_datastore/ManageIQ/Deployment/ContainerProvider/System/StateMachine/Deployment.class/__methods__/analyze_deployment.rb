def analyze_deployment
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
  $evm.root['deployment_method'] = $evm.root['automation_task'].automation_request.options[:attrs][:deployment_method]

  if $evm.root['deployment_method'] == "managed_provision"
    $evm.root['ae_next_state'] = "provision"
  else
    $evm.root['ae_next_state'] = "check_ssh"
    $evm.root['deployment_master'] = $evm.root['automation_task'].automation_request.options[:attrs][:deployment_master]
    $evm.root['masters'] = $evm.root['automation_task'].automation_request.options[:attrs][:masters]
    $evm.root['nodes'] = $evm.root['automation_task'].automation_request.options[:attrs][:nodes]
  end

  $evm.root['deployment_type'] = $evm.root['automation_task'].automation_request.options[:attrs][:deployment_type]
  $evm.root['user'] = $evm.root['automation_task'].automation_request.options[:attrs][:ssh_username]
  $evm.root['password'] = $evm.root['automation_task'].automation_request.options[:attrs][:password]
  $evm.root['provider_name'] = $evm.root['automation_task'].automation_request.options[:attrs][:provider_name]
  $evm.root['private_key'] = $evm.root['automation_task'].automation_request.options[:attrs][:ssh_private_key]
  $evm.root['manageiq_url'] = $evm.root['automation_task'].automation_request.options[:attrs][:manageiq_url]

  # params needed for rhel subscriptions
  $evm.root['rhsub_user'] = $evm.root['automation_task'].automation_request.options[:attrs][:rhsub_user]
  $evm.root['rhsub_pass'] = $evm.root['automation_task'].automation_request.options[:attrs][:rhsub_pass]
  $evm.root['rhsub_pool'] = $evm.root['automation_task'].automation_request.options[:attrs][:rhsub_pool]

  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "deployment type - #{$evm.root['deployment_method']}"
  $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
           "| Message: #{$evm.root['automation_task'].message}")
end

analyze_deployment

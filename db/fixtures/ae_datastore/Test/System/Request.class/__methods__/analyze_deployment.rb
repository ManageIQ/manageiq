def analyze_deployment()
  $evm.root['Phase'] = "check ssh"
  $evm.log(:info, "********************** analyze deployment ***************************")
  deployment_type = $evm.root['automation_task'].automation_request.options[:attrs][:type]
  # deployment_type = "managed existing"
  case deployment_type
  when "managed existing"
    $evm.root['ae_next_state'] = "clean_up" #"pre_validate"
    $evm.root['masters'] = $evm.root['automation_task'].automation_request.options[:attrs][:masters]
    $evm.root['nodes'] = $evm.root['automation_task'].automation_request.options[:attrs][:nodes]
  when "managed_provision"
    $evm.root['ae_next_state'] = "provision"
  when "not_managed"
    $evm.root['ae_next_state'] = "check_ssh"
  end

  $evm.root['Phase'] = "analyze_deployment"

  #TODO: find a cleaner way to do that
  $evm.root['deployment_type'] = deployment_type

  $evm.root['user'] = $evm.root['automation_task'].automation_request.options[:attrs][:user]
  $evm.root['password'] = $evm.root['automation_task'].automation_request.options[:attrs][:password]
  $evm.root['ae_result'] = "ok"
  $evm.root['Message'] = "deployment type: #{deployment_type}"

  #TODO: find a solution to run those from log_state method
  $evm.log(:info, "#{$evm.root['Phase']} : #{$evm.root['ae_result']} : #{$evm.root['Message']}")
  $evm.log(:info, "Next State: #{$evm.root['ae_next_state']}")
end

analyze_deployment()
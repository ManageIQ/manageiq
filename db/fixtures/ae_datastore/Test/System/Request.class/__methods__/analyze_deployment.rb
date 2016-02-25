def analyze_deployment()
  $evm.log(:info, "********************** analyze deployment ***************************")
  # $evm.log(:info, )
  deployment_type = $evm.root['automation_task'].automation_request.options[:attrs][:type]
  case deployment_type
  when "managed existing"
    $evm.root['ae_next_state'] = "pre_validate"
  when "managed_provision"
    $evm.root['ae_next_state'] = "provision"
  when "not_managed"
    $evm.root['ae_next_state'] = "check_ssh"
  end
  $evm.log(:info, "deployment type: #{deployment_type}")
end

analyze_deployment
$evm.log(:info, "********************** #{$evm.root['ae_state']} ******************************")
begin
  $evm.root['container_deployment'] ||= $evm.vmdb(:container_deployment).find(
    $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id]
  )
  result = $evm.root['container_deployment'].run_playbook_command("atomic-openshift-installer -u -c /usr/share/ansible/openshift-ansible/inventory.yaml install")
  if result[:finished]
    $evm.root['ae_result'] = $evm.root['container_deployment'].analyze_ansible_output(result[:stdout]) ? "ok" : "error"
    $evm.root['ae_reason'] = "Error: ansible playbook failed to deploy cluster"
  else
    $evm.log(:info, "*********  deployment playbook is runing waiting for it to finish ************")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  end
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end

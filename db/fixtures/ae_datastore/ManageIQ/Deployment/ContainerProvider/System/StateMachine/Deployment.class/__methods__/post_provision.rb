def assign_vms_to_deployment_nodes
  $evm.root['container_deployment'].assign_container_deployment_nodes
  $evm.root['deployment_master'] = $evm.root['container_deployment'].roles_addresses("deployment_master")
  $evm.root['inventory'] = $evm.root['container_deployment'].generate_ansible_yaml
  $evm.root['rhel_subscribe_inventory'] = $evm.root['container_deployment'].generate_ansible_inventory_for_subscription
end

def wait_for_ip_addresses
  $evm.root['state'] = "post_provision"
  $evm.root['automation_task'].message = "Trying to receive ips"
  if $evm.root['container_deployment'].provisioned_ips_set?
    assign_vms_to_deployment_nodes
    $evm.root['ae_result'] = 'ok'
  else
    $evm.log(:info, "*********  Post-Provision waiting on ips ************")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '2.minute'
    refresh_provider
  end
end

def refresh_provider
  deploy_on_provider = $evm.vmdb(:ext_management_system).find($evm.root['automation_task'].automation_request.options[:attrs][:provision_provider_id])
  if deploy_on_provider
    deploy_on_provider.refresh
  else
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = "Couldn't find the underline provider for refresh"
  end
end

begin
  $evm.root['container_deployment'] ||= $evm.vmdb(:container_deployment).find(
    $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id]
  )
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
  wait_for_ip_addresses
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end

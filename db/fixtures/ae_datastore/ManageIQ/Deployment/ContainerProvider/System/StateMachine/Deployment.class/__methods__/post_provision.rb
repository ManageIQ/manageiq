def find_vm_by_tag(tag)
  tag = "/managed/miq_openstack_deploy/#{tag}_#{$evm.root['automation_task'][:id]}"
  $evm.vmdb(:vm).find_tagged_with(:any => tag, :ns => "*")
end

def assign_vms_to_deployment_nodes(masters, nodes)
  deployment = $evm.vmdb(:container_deployment).find(
    $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id])
  masters.each do |master|
    deployment.assign_container_deployment_node(master.id, "master")
  end
  nodes.each do |node|
    deployment.assign_container_deployment_node(node.id, "node")
  end
  $evm.root['deployment_master'] = deployment.roles_addresses("deployment_master")
  $evm.root['inventory'] = deployment.regenerate_ansible_inventory
  $evm.root['rhel_subscribe_inventory'] =  deployment.regenerate_ansible_subscription_inventory
end

def missing_subscription_fields?
  $evm.root['rhsub_user'].nil? || $evm.root['rhsub_pass'].nil? || $evm.root['rhsub_sku'].nil?
end

def extract_ips(vms)
  ips = []
  vms.each do |vm|
    ips << vm.hardware.ipaddresses.last unless vm.hardware.ipaddresses.empty?
  end
  ips
end

def wait_for_ip_adresses
  $evm.root['state'] = "post_provision"
  $evm.root['automation_task'].message = "Trying to receive ips"
  tagged_vms_masters = find_vm_by_tag("master")
  tagged_vms_nodes = find_vm_by_tag("node")
  masters_ips = extract_ips(tagged_vms_masters)
  nodes_ips = extract_ips(tagged_vms_nodes)
  if nodes_ips.count + masters_ips.count == tagged_vms_masters.count + tagged_vms_nodes.count
    assign_vms_to_deployment_nodes(tagged_vms_masters, tagged_vms_nodes)
    $evm.root['masters'] = masters_ips
    $evm.root['nodes'] = nodes_ips
    $evm.root['ae_result'] = 'ok'
    $evm.root['container_deployment'] = $evm.vmdb(:container_deployment).find(
      $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id])
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

$evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
wait_for_ip_adresses

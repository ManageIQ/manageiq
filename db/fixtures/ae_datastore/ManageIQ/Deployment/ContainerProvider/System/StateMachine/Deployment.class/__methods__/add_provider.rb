gem "net-ssh", "=3.2.0.rc2"
require 'net/ssh'

DEPLOYMENT_TYPES = {
  :origin                 => "ManageIQ::Providers::Openshift::ContainerManager",
  :openshift_enterprise   => "ManageIQ::Providers::OpenshiftEnterprise::ContainerManager",
  :atomic                 => "ManageIQ::Providers::Atomic::ContainerManager",
  :atomic_enterprise      => "ManageIQ::Providers::AtomicEnterprise::ContainerManager"
}. freeze

def provider_token
  token = ""
  Net::SSH.start($evm.root['deployment_master'], $evm.root['ssh_username'], :paranoid => false, :forward_agent => true, :agent_socket_factory => ->{ UNIXSocket.open($evm.root['agent_socket']) }) do |ssh|
    cmd = "oc get secrets `oc describe serviceaccount management-admin -n management-infra | awk '/Tokens:/ { print $2 }'` --template '{{.data.token}}' -n management-infra | base64 -d"
    token = ssh.exec!(cmd)
  end
  token
end

def add_provider
  $evm.log(:info, "**************** #{$evm.root['ae_state']} ****************")
  token = provider_token
  begin
    deployment = $evm.vmdb(:container_deployment).find(
      $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id])
    result = deployment.add_deployment_provider(
      :provider_type      => DEPLOYMENT_TYPES[$evm.root['deployment_type'].gsub("-", "_").to_sym],
      :provider_name      => $evm.root['provider_name'],
      :provider_port      => "8443",
      :provider_hostname  => $evm.root['deployment_master'],
      :provider_ipaddress => $evm.root['deployment_master'],
      :auth_type          => "bearer",
      :auth_key           => token)

    $evm.log(:info, "result: #{result}")
    if result
      provider = deployment.deployed_ems
      $evm.root['ae_result'] = "ok"
      $evm.root['automation_task'].message = "successfully added #{$evm.root['provider_name']} as a container provider"
    else
      $evm.root['ae_result'] = "error"
      $evm.root['automation_task'].message = "failed to add #{$evm.root['provider_name']} as a container provider"
    end
  rescue Exception => e
    $evm.log(:info, e)
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = e.message
  end

  $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
           "| Message: #{$evm.root['automation_task'].message}")
end

add_provider

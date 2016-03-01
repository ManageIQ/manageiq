require 'net/ssh'

DEPLOYMENT_TYPES = {
  :openshift_origin     => "ManageIQ::Providers::Openshift::ContainerManager",
  :openshift_enterprise => "ManageIQ::Providers::OpenshiftEnterprise::ContainerManager",
  :atomic               => "ManageIQ::Providers::Atomic::ContainerManager",
  :atomic_enterprise    => "ManageIQ::Providers::AtomicEnterprise::ContainerManager"
}. freeze

def provider_token
  token = ""
  Net::SSH.start($evm.root['deployment_master'], $evm.root['user'], :paranoid => false, :forward_agent => true,
                 :key_data => $evm.root['private_key']) do |ssh|
    cmd = "oc get -n management-infra sa/management-admin --template='{{range .secrets}}{{printf " + '"%s\n"' \
          " .name}}{{end}}' | grep token"
    token_key = ssh.exec!(cmd)
    token_key.delete!("\n")
    cmd = "oc get -n management-infra secrets #{token_key} --template='{{.data.token}}' | base64 -d"
    token = ssh.exec!(cmd)
  end
  token
end

def add_provider
  $evm.log(:info, "**************** #{$evm.root['ae_state']} ****************")
  token = provider_token
  begin
    deployment = $evm.vmdb(:deployment).find(
      $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id])
    result = deployment.add_deployment_provider(
      :provider_type      => DEPLOYMENT_TYPES[$evm.root['deployment_type'].to_sym],
      :provider_name      => $evm.root['provider_name'],
      :provider_port      => "8443",
      :provider_hostname  => $evm.root['deployment_master'],
      :provider_ipaddress => $evm.root['deployment_master'],
      :auth_type          => "bearer",
      :auth_key           => token)

    $evm.log(:info, "result: #{result}")
    if result[0]
      provider = deployment.deployed_ext_management_system
      provider.refresh
      $evm.root['ae_result'] = "ok"
      $evm.root['automation_task'].message = "successfully added #{$evm.root['provider_name']} as a container provider"
    else
      $evm.log(:error, result[1])
      $evm.root['ae_result'] = "error"
      $evm.root['automation_task'].message = "failed to add #{$evm.root['provider_name']} as a container provider"
    end
  rescue StandardError => e
    $evm.root['ae_result'] = "error"
    $evm.log(:error, e)
    $evm.root['automation_task'].message = "failed to add #{$evm.root['provider_name']} as a container provider"
  end

  $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
           "| Message: #{$evm.root['automation_task'].message}")
end

add_provider

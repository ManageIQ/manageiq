require 'net/ssh'
require 'rest_client'

def get_provider_token
  token = ""
  Net::SSH.start($evm.root['deployment_master'], $evm.root['user'], :paranoid => false, :forward_agent => true, :keys => [$evm.root['ssh_key_path']]) do |ssh|
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
  $evm.root['state'] = "add_provider"
  $evm.log(:info, "**************** add_provider ****************")
  deployment_master = $evm.root['deployment_master']
  token = get_provider_token

  url = $evm.root['manageiq_url']
  query = "/api/providers"
  post_params = {
    :credentials => {
      :auth_type => "bearer",
      :auth_key  => token
    },
    :type        => "ManageIQ::Providers::Openshift::ContainerManager",
    :name        => $evm.root['provider_name'],
    :port        => "8443",
    :hostname    => deployment_master,
    :ipaddress   => deployment_master
  }.to_json

  begin
    rest_return = RestClient::Request.execute(
      :method     => :post,
      :url        => url + query,
      :user       => $evm.root['manageiq_user'],
      :password   => $evm.root['manageiq_password'],
      :headers    => {:accept => :json},
      :payload    => post_params,
      :verify_ssl => false)

    result = JSON.parse(rest_return.body)
    $evm.root['provider_id'] = result["results"].first["id"]

    if $evm.root['provider_id']
      $evm.root['ae_result'] = "ok"
      $evm.root['automation_task'].message = "successfully added #{$evm.root['provider_name']} as a container provider"
    end
  rescue Exception => e
    $evm.root['ae_result'] = "error"
    error = JSON.parse(e.response.body)
    $evm.log(:error, "Kind: #{e.message} | Message: #{error['error']['message']}")
    $evm.root['automation_task'].message = "failed to add #{$evm.root['provider_name']} as a container provider"
  ensure
    $evm.log(:info, "State: #{$evm.root['state']} | Result: #{$evm.root['ae_result']} "\
             "| Message: #{$evm.root['automation_task'].message}")
  end
end

add_provider

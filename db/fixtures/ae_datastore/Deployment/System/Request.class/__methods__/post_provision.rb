require 'rest_client'

def assing_to_evm(masters_ips, nodes_ips)
  $evm.root['deployment_master'] = masters_ips.shift
  $evm.root['masters'] = []
  masters_ips.each do |master_ip|
    $evm.root['masters'] << master_ip
  end
  $evm.root['nodes'] = []
  nodes_ips.each do |node_ips|
    $evm.root['nodes'] << node_ips
  end
  $evm.root['user'] = 'root'
end

def get_custom_tag(type)
  type + "_#{$evm.root['automation_task'][:id]}"
end

def wait_for_ip_adresses
  $evm.root['automation_task'].message = "Trying to recieve ips"
  nodes_tag = "/managed/deploy/" + "node" + "_#{$evm.root['automation_task'][:id]}"
  masters_tag = "/managed/deploy/" + "master" + "_#{$evm.root['automation_task'][:id]}"
  tagged_vms_masters = $evm.vmdb(:vm).find_tagged_with(:any => masters_tag, :ns => "*")
  tagged_vms_nodes = $evm.vmdb(:vm).find_tagged_with(:any => nodes_tag, :ns => "*")
  masters_ips = []
  nodes_ips = []
  tagged_vms_masters.each do |vm|
    masters_ips << vm.hardware.ipaddresses[0] unless vm.hardware.ipaddresses.empty?
  end
  tagged_vms_nodes.each do |vm|
    nodes_ips << vm.hardware.ipaddresses[0] unless vm.hardware.ipaddresses.empty?
  end

  if nodes_ips.count + masters_ips.count == tagged_vms_masters.count + tagged_vms_nodes.count
    assing_to_evm(masters_ips, nodes_ips)
    $evm.root['ae_result'] = 'ok'
  else
    $evm.log(:info, "*********  Post-Provision waiting on ips ************")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '2.minute'
  end
end

def refresh_provider
  $evm.log(:info, "*********  Post-Provision refreshing provider ************")
  url = $evm.root['automation_task'].automation_request.options[:attrs][:manageiq_url].to_s
  query = "/api/providers/" + $evm.root['automation_task'].automation_request.options[:attrs][:provider_id].to_s
  post_params = {
    :action => "refresh"
  }.to_json
  RestClient::Request.execute(
    :method     => :post,
    :url        => url + query,
    :user       => $evm.root['automation_task'].automation_request.options[:attrs][:username],
    :password   => $evm.root['automation_task'].automation_request.options[:attrs][:password],
    :headers    => {:accept => :json},
    :payload    => post_params,
    :verify_ssl => false)
end

wait_for_ip_adresses
refresh_provider

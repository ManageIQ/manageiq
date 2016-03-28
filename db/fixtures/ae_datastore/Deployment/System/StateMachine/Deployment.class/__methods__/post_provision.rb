require 'rest_client'
require 'net/ssh'

def rhn_user
  $evm.root['automation_task'].automation_request.options[:attrs][:rhn_user]
end

def rhn_password
  $evm.root['automation_task'].automation_request.options[:attrs][:rhn_pass]
end

def rhn_pool_id
  $evm.root['automation_task'].automation_request.options[:attrs][:rhn_pool_id]
end

# need to check if clients need to add pool or just employees
# need to have activation key command as well
COMMANDS = [
  "subscription-manager register --username=#{rhn_user}  --password=#{rhn_password}",
  "subscription-manager attach --pool=#{rhn_pool_id}",
  "subscription-manager repos --disable=\"*\"",
  "subscription-manager repos --enable=\"rhel-7-server-rh-common-rpms\" --enable=\"rhel-7-server-rpms\" --enable=\"rhel-7-server-extras-rpms\" --enable=\"rhel-7-server-ose-3.1-rpms\""
].freeze

def find_vm_by_tag(tag)
  $evm.vmdb(:vm).find_tagged_with(:any => tag, :ns => "*")
end

def tagged_vms
  nodes_tag = "/managed/deploy/" + "node" + "_#{$evm.root['automation_task'][:id]}"
  masters_tag = "/managed/deploy/" + "master" + "_#{$evm.root['automation_task'][:id]}"
  return find_vm_by_tag(masters_tag), find_vm_by_tag(nodes_tag)
end

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

def missing_subscription_fields?
  rhn_user.nil? || rhn_password.nil? || rhn_pool_id.nil?
end

def subscribe_if_rhel
  Net::SSH.start($evm.root['deployment_master'], $evm.root['user'], :paranoid => false, :forward_agent => true,
                 :key_data => $evm.root['private_key']) do |ssh|
    $evm.log(:info, "Connected to deployment master , ip address: #{$evm.root['deployment_master']} Checking if RHEL")
    type = ssh.exec!("cat /etc/*release")
    subscrption_needed = type.include? "REDHAT_SUPPORT_PRODUCT=\"Red Hat Enterprise Linux\""
    if subscrption_needed && missing_subscription_fields?
      $evm.root['ae_result'] = "error"
      $evm.log(:info, "Missing credentials for rhn subscription")
      $evm.root['automation_task'].message = "Missing credentials for rhn subscription"
    elsif subscrption_needed
      $evm.log(:info, "RHN subscribing starting")
      COMMANDS.each do |cmd|
        ssh.exec!(cmd)
      end
    end
  end
rescue
  $evm.root['ae_result'] = "error"
  $evm.root['automation_task'].message = "Cannot connect to deployment master " \
                                         "(#{$evm.root['deployment_master']}) via ssh"
ensure
  $evm.log(:info, "State: #{$evm.root['state']} | Result: #{$evm.root['ae_result']} "\
           "| Message: #{$evm.root['automation_task'].message}")
end

def extract_ips(vm_array)
  ip_array = []
  vm_array.each do |vm|
    ip_array << vm.hardware.ipaddresses[0] unless vm.hardware.ipaddresses.empty?
  end
  ip_array
end

def wait_for_ip_adresses
  $evm.root['state'] = "post_provision"
  $evm.root['automation_task'].message = "Trying to recieve ips"
  tagged_vms_masters, tagged_vms_nodes = tagged_vms
  masters_ips = extract_ips(tagged_vms_masters)
  nodes_ips = extract_ips(tagged_vms_nodes)
  if nodes_ips.count + masters_ips.count == tagged_vms_masters.count + tagged_vms_nodes.count
    $evm.log(:info, "*********  nodes ips ************")
    $evm.log(:info, nodes_ips.inspect)
    $evm.log(:info, "*********  masters ips ************")
    $evm.log(:info, masters_ips.inspect)
    assing_to_evm(masters_ips, nodes_ips)
    subscribe_if_rhel
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
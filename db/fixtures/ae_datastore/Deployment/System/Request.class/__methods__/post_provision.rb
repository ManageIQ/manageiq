def ssh_copy_id(ip, user = 'root', passsword = '1234')
  cmd = "sshpass -p #{passsword} ssh-copy-id #{user}@#{ip} -o 'StrictHostKeyChecking no'"
  `#{cmd}`
end

def add_ssh_key(ips)
  ips.each do |ip|
    # need to add user and password will be taked from the api request
    ssh_copy_id(ip, 'root', $evm.root['automation_task'].automation_request.options[:attrs][:root_password])
  end
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
end

def get_custom_tag(type)
  type + "_#{$evm.root['automation_task'][:id]}"
end

def get_tagged_tasks(tagged_vms_masters, tagged_vms_nodes)
  nodes_tag = "/managed/deploy/" + get_custom_tag("node")
  masters_tag = "/managed/deploy/" + get_custom_tag("master")
  tagged_vms_masters << $evm.vmdb(:vm).find_tagged_with(:all => masters_tag, :ns => "*")
  tagged_vms_nodes << $evm.vmdb(:vm).find_tagged_with(:all => nodes_tag, :ns => "*")
end

def wait_for_ip_adresses
  $evm.log(:info, '*********  Post provision waiting on ip address  ************')
  $evm.root['automation_task'].message = "Trying to recieve ips"
  tagged_vms_masters = []
  tagged_vms_nodes = []
  get_tagged_tasks(tagged_vms_masters, tagged_vms_nodes)
  masters_ips = []
  nodes_ips = []
  tagged_vms_masters[0].each do |vm|
    masters_ips << vm.hardware.ipaddresses[0] unless vm.hardware.ipaddresses.empty?
  end
  tagged_vms_nodes[0].each do |vm|
    nodes_ips << vm.hardware.ipaddresses[0] unless vm.hardware.ipaddresses.empty?
  end
  if nodes_ips.count + masters_ips.count == tagged_vms_masters.count + tagged_vms_nodes.count
    assing_to_evm(masters_ips, nodes_ips)
    add_ssh_key(masters_ips + nodes_ips)
    $evm.root['ae_result'] = 'ok'
  else
    $evm.log(:info, "*********  Post-Provision waiting on ips ************")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  end
end

wait_for_ip_adresses

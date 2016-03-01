INVENTORY_FILE = 'inventory.yaml'

def make_ansible_inventory_file(master_ip, masters_ips, nodes_ips, user)
  $evm.log(:info, "Creating inventory file")

  template = "
[OSEv3:children]
masters
nodes

[masters:vars]
ansible_ssh_user=#{user}
ansible_sudo=true
deployment_type=origin
#openshift_use_manageiq=True

[nodes:vars]
ansible_ssh_user=#{user}
ansible_sudo=true
deployment_type=origin
#openshift_use_manageiq=True

[masters]
#{master_ip} ansible_connection=local openshift_scheduleable=True
#{masters_ips.join("\n") unless masters_ips.empty?}

[nodes]
#{nodes_ips.join("\n")}
  "

  File.open(INVENTORY_FILE, 'w') do |f|
    f.write(template)
  end
end

def create_ansible_inventory_files
  $evm.root['state'] = "create_ansible_files"
  $evm.log(:info, "********************** creating ansible files ***************************")
  nodes = replace_connecting_master_ip($evm.root['nodes'], $evm.root['deployment_master'])
  make_ansible_inventory_file($evm.root['deployment_master'], $evm.root['masters'], nodes, $evm.root['user'])
end

def replace_connecting_master_ip(nodes, master_ip)
  nodes.each_with_index do |cell, index|
    if cell.include? master_ip
      nodes[index] = "#{master_ip}              ansible_connection=local"
    end
  end
  nodes
end

create_ansible_inventory_files
$evm.log(:info, "State: #{$evm.root['state']} | Result: #{$evm.root['ae_result']} "\
         "| Message: #{$evm.root['automation_task'].message}")
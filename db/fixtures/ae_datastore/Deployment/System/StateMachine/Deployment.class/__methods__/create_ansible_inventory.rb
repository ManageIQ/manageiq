INVENTORY_FILE = 'inventory.yaml'.freeze

def create_inventory_template(deployment_master, masters, nodes, user)
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
#{deployment_master} ansible_connection=local openshift_scheduleable=True
#{masters.join("\n") unless masters.empty?}

[nodes]
#{nodes.join("\n")}
  "

  template
end

def replace_connecting_master_ip(nodes, master_ip)
  nodes.each_with_index do |node, index|
    if node.include? master_ip
      nodes[index] = "#{master_ip}              ansible_connection=local"
    end
  end
  nodes
end

def create_ansible_inventory_file
  $evm.root['state'] = "create_ansible_inventory"
  $evm.log(:info, "********************** creating ansible inventory file ***************************")
  nodes = replace_connecting_master_ip($evm.root['nodes'], $evm.root['deployment_master'])
  template = create_inventory_template($evm.root['deployment_master'], $evm.root['masters'], nodes, $evm.root['user'])

  begin
    File.open(INVENTORY_FILE, 'w') do |f|
      f.write(template)
    end
    $evm.root['ae_result'] = "ok"
    $evm.root['automation_task'].message = "successfully created ansible inventory file"
  rescue StandardError => e
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = "failed to create ansible inventory file: " + e
  ensure
    $evm.log(:info, "State: #{$evm.root['state']} | Result: #{$evm.root['ae_result']} "\
             "| Message: #{$evm.root['automation_task'].message}")
  end
end

create_ansible_inventory_file

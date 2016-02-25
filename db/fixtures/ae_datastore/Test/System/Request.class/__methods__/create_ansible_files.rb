DEPLOY_BOOK = 'deploy_book.yaml'
INVENTORY_FILE = 'to_send_inventory.yaml'
MASTER_INVENTORY_FILE = 'master_inventory.yaml'
LOCAL_BOOK = 'local_book.yaml'

def make_local_playbook
  $evm.log(:info, "installing Ansbile and creating local ansible deploy book")
  template = "
---
- hosts: all
  tasks:
  - replace: dest=/etc/ansible/ansible.cfg regexp=\"^#host_key_checking = False\" replace=\"host_key_checking = False\"
  - replace: dest=/etc/ansible/ansible.cfg regexp=\"^#ssh_args =\" replace=\"ssh_args = -o ForwardAgent=yes\"
  "
  File.open(LOCAL_BOOK, 'w') do |f|
    f.write(template)
  end
end

def make_deploy_playbook(user)
  $evm.log(:info, "Creating ansible deploy book")

  template = "
---
- hosts: master
  remote_user: #{user}
  sudo: yes
  tasks:
  - name: add git package
    yum: name=git state=present

  - name: clone git
    git: repo=https://github.com/openshift/openshift-ansible.git dest=/tmp/openshift-ansible
    sudo: true

  - name: Create the inventory file
    copy: src=../../to_send_inventory.yaml
          dest=/tmp/openshift-ansible/
          mode=0644

  - name: add ansible package
    yum: name=ansible state=present

  - name: add pyOpenSSL package
    yum: name=pyOpenSSL state=present

  - name: removing fingerprint
    replace: dest=/etc/ansible/ansible.cfg regexp=\"^#host_key_checking = False\" replace=\"host_key_checking = False\"

  - name: allowing agent forwarding
    replace: dest=/etc/ansible/ansible.cfg regexp=\"^#ssh_args =\" replace=\"ssh_args = -o ForwardAgent=yes\"

  "
  File.open(DEPLOY_BOOK, 'w') do |f|
    f.write(template)
  end
end

def make_ansible_inventory_file(master_ip, masters_ips, slaves_ips, user)
  $evm.log(:info, "Creating to_send inv file")

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
localhost ansible_connection=local openshift_scheduleable=True

[nodes]
#{slaves_ips[0]}
#{slaves_ips[1]}
  "
  File.open(INVENTORY_FILE, 'w') do |f|
    f.write(template)
  end
end

def make_ansible_master_inventory_file(master_ip, master_user)
  $evm.log(:info, "Creating master inv file")

  template = "
---
[master]
#{master_ip}

[master:vars]
ansible_ssh_user=#{master_user}
ansible_sudo=true
deployment_type=origin
#openshift_use_manageiq=True
"

  File.open(MASTER_INVENTORY_FILE, 'w') do |f|
    f.write(template)
  end
end


def verify_ansibe_files_creation(ansible_files)
  ansible_files.each do |f|
    unless File.file?(f)
      $evm.root['ae_result'] = "error"
    end
  end
  $evm.root['ae_result'] = "ok"
end

def create_ansible_files()
  $evm.root['Phase'] = "create_ansible_files"
  $evm.root['automation_task'].message = "Create_ansible_files"
  $evm.log(:info, "********************** creating ansible files ***************************")
  make_local_playbook
  master = $evm.root['automation_task'].automation_request.options[:attrs][:connect_through_master_ip]
  masters = $evm.root['automation_task'].automation_request.options[:attrs][:masters_ips]
  nodes = $evm.root['automation_task'].automation_request.options[:attrs][:nodes_ips]
  nodes = replace_connecting_master_ip(nodes, master)
  user = $evm.root['automation_task'].automation_request.options[:attrs][:user]
  make_deploy_playbook(user)
  make_ansible_master_inventory_file( master, user)
  make_ansible_inventory_file(master, masters, [nodes[0], nodes[1]],user)
  verify_ansibe_files_creation([DEPLOY_BOOK, INVENTORY_FILE, MASTER_INVENTORY_FILE, LOCAL_BOOK])
  $evm.log(:info, "#{$evm.root['Phase']} : #{$evm.root['ae_result']} : #{$evm.root['Message']}")
end

def replace_connecting_master_ip(nodes, master_ip)
  nodes.each_with_index do |cell, index|
    if cell.include? master_ip
          nodes[index] = "localhost              ansible_connection=local"
    end
  end
  nodes
end

create_ansible_files()
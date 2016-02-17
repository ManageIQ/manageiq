def ansible_deploy()
  $evm.log(:info, "Started ansible deployment")
  system "ansible-playbook extras/playbooks/deploy_book.yaml -i master_inventory.yaml"
end

def make_deploy_playbook(user)
  $evm.log(:info, "Creating ansible deploy book")

  template = "
---
- hosts: master
  remote_user: #{user}
  tasks:

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

  "
  # - name: Run playbook
  # shell: ansible-playbook /tmp/openshift-ansible/playbooks/byo/config.yml -i /tmp/openshift-ansible/to_send_inventory.yaml
  # "
  File.open('extras/playbooks/deploy_book.yaml', 'w') do |f|
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

  File.open('master_inventory.yaml', 'w') do |f|
    f.write(template)
  end
end

def make_ansible_inventory_file(master_ip, slaves_ips, user)
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
#{master_ip} openshift_scheduleable=True

[nodes]
#{master_ip}
#{slaves_ips[1]}
  "
  File.open('to_send_inventory.yaml', 'w') do |f|
    f.write(template)
  end
end

# make_deploy_playbook("")
# make_ansible_master_inventory_file("", "")
# make_ansible_inventory_file("", ["", ""],"")
# ansible_deploy()
# system "ssh ip ansible-playbook /tmp/openshift-ansible/playbooks/byo/config.yml -i /tmp/openshift-ansible/to_send_inventory.yaml"
# $evm.log(:info, $evm.root['automation_task'].automation_request.inspect)

$evm.log(:info, "********************** deployment ******************************")

exit MIQ_OK

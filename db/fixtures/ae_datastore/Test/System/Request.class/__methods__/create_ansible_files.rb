DEPLOY_BOOK = 'extras/playbooks/deploy_book.yaml'
INVENTORY_FILE = 'to_send_inventory.yaml'
MASTER_INVENTORY_FILE = 'master_inventory.yaml'

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
  File.open(DEPLOY_BOOK, 'w') do |f|
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
  $evm.log(:info, "********************** creating ansible files ***************************")
  # make_deploy_playbook("")
  # make_ansible_master_inventory_file("", "")
  # make_ansible_inventory_file("", ["", ""],"")
  verify_ansibe_files_creation([DEPLOY_BOOK, INVENTORY_FILE, MASTER_INVENTORY_FILE])
  $evm.log(:info, "#{$evm.root['Phase']} : #{$evm.root['ae_result']} : #{$evm.root['Message']}")
end

create_ansible_files()
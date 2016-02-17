def ansible_deploy()
  $evm.root['Phase'] = "check ssh"
  $evm.log(:info, "********************** deployment ******************************")
  system "ssh ip ansible-playbook /tmp/openshift-ansible/playbooks/byo/config.yml -i /tmp/openshift-ansible/to_send_inventory.yaml"

  #TODO: think how to verify deployment (poll from ansible.log on master perhaps)
  $evm.root['ae_result'] = "ok"
  $evm.root['Message'] = "successfuly deployed Ansible"
end

ansible_deploy

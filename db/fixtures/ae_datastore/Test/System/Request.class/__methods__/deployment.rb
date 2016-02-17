def ansible_deploy()
  $evm.log(:info, "Started ansible deployment")
  system "ansible-playbook extras/playbooks/deploy_book.yaml -i master_inventory.yaml"
end

# make_deploy_playbook("")
# make_ansible_master_inventory_file("", "")
# make_ansible_inventory_file("", ["", ""],"")
# ansible_deploy()
# system "ssh ip ansible-playbook /tmp/openshift-ansible/playbooks/byo/config.yml -i /tmp/openshift-ansible/to_send_inventory.yaml"
# $evm.log(:info, $evm.root['automation_task'].automation_request.inspect)

$evm.log(:info, "********************** deployment ******************************")

exit MIQ_OK

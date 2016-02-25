$evm.log(:info, "********************** deployment ******************************")
# can we count on having ansible installed?
# output = `sudo yum install ansible -y`
system "sudo ansible-playbook #{LOCAL_BOOK} -i 'localhost,' --connection=local"
master = $evm.root['automation_task'].automation_request.options[:attrs][:connect_through_master_ip]
user = $evm.root['automation_task'].automation_request.options[:attrs][:user]
cmd = "ssh "+ user + "@" + master +" -A ansible-playbook /tmp/openshift-ansible/playbooks/byo/config.yml -i /tmp/openshift-ansible/to_send_inventory.yaml"
output =  `#{cmd}`
$evm.log(:info, output)


exit MIQ_OK

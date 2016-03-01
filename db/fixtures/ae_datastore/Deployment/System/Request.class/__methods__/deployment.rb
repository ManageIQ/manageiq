def analyze_ansible_output(output)
  result = output.rpartition('PLAY RECAP ********************************************************************').last
  result = result.split(" ")
  passed = true
  result.each do |cell|
    if((cell.include?("failed") || cell.include?("unreachable")) && (!cell.include?("=0")))
      passed = false
      $evm.root['ae_result'] = "error"
      $evm.root['automation_task'].message = "deployment failed"
      break
    end
  end

  if passed
    $evm.root['automation_task'].message = "successful deployment"
  end
  passed
end

$evm.log(:info, "********************** deployment ******************************")
$evm.root['state'] = "deployment"

master = $evm.root['automation_task'].automation_request.options[:attrs][:deployment_master]
user = $evm.root['automation_task'].automation_request.options[:attrs][:username]
cmd = "ssh -o 'StrictHostKeyChecking no' -A -t -t " + user + "@" + master +" host_key_checking='False' ssh_args=-o ForwardAgent=yes ansible-playbook /tmp/openshift-ansible/playbooks/byo/config.yml -i /tmp/openshift-ansible/inventory.yaml"

output =  `#{cmd}`
$evm.root['ae_result'] = analyze_ansible_output(output) ? "ok" : "error"
$evm.log(:info, "State: #{$evm.root['state']} | Result: #{$evm.root['ae_result']} "\
         "| Message: #{$evm.root['automation_task'].message}")


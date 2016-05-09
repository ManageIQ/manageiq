require 'net/ssh'

def analyze_ansible_output(output)
  results = output.rpartition('PLAY RECAP ********************************************************************').last
  results = results.split("\r\n")
  results.shift
  passed = true
  results.each do |node_result|
    unless node_result.include?("unreachable=0") && node_result.include?("failed=0")
      passed = false
      $evm.root['ae_result'] = "error"
      $evm.root['automation_task'].message = "deployment failed"
      next
    end
    break unless passed
  end

  if passed
    $evm.root['automation_task'].message = "successful deployment"
  end
  passed
end

$evm.log(:info, "********************** #{$evm.root['ae_state']} ******************************")
agent_socket = "/tmp/ssh_manageiq/ssh_manageiq_#{$evm.root['automation_task'].automation_request.options[:attrs][:deployment_id]}"
Net::SSH.start($evm.root['deployment_master'], $evm.root['user'], :paranoid => false, :forward_agent => true, :agent_socket_factory => ->{ UNIXSocket.open(agent_socket) },
               :key_data => $evm.root['private_key']) do |ssh|
  $evm.log(:info, "Starting deployment on master, ip address: #{$evm.root['deployment_master']}")
  ssh.exec!("ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml -i /usr/share/ansible/openshift-ansible/inventory.yaml")
end

# deploy_cmd = "ssh -o 'StrictHostKeyChecking no' -A -t -t #{$evm.root['user']}@#{$evm.root['deployment_master']}" \
#              " host_key_checking='False' ssh_args=-o ForwardAgent=yes " \
#              "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml -i "\
#              "/usr/share/ansible/openshift-ansible/inventory.yaml"

output = `#{deploy_cmd}`
$evm.root['ae_result'] = analyze_ansible_output(output) ? "ok" : "error"
$evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
         "| Message: #{$evm.root['automation_task'].message}")

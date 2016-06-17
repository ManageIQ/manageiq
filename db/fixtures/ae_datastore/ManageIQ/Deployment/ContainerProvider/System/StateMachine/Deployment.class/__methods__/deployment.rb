gem "net-ssh", "=3.2.0.rc2"
require 'net/ssh'

def analyze_ansible_output(output)
  results = output.rpartition('PLAY RECAP ********************************************************************').last
  results = results.split("\r\n")
  results.shift
  passed = true
  results.each do |node_result|
    unless node_result.include?("unreachable=0") && node_result.include?("failed=0")
      passed                               = false
      $evm.root['ae_result']               = "error"
      $evm.root['automation_task'].message = "deployment failed"
      next
    end
    break unless passed
  end
end

def ssh_exec!(ssh, command)
  stdout_data, stderr_data = "", ""
  exit_code, exit_signal = nil, nil

  ssh.open_channel do |channel|
    channel.exec("ssh -A -o 'StrictHostKeyChecking no' -t -t #{$evm.root['ssh_username']}@#{$evm.root['deployment_master']} " \
                 + command) do |_, success|
      raise StandardError, "Command \"#{command}\" was unable to execute" unless success

      channel.on_data do |_, data|
        stdout_data += data
      end

      channel.on_extended_data do |_, _, data|
        stderr_data += data
      end

      channel.on_request("exit-status") do |_, data|
        exit_code = data.read_long
      end

      channel.on_request("exit-signal") do |_, data|
        exit_signal = data.read_long
      end
    end
  end
  ssh.loop
  {
    :stdout      => stdout_data,
    :stderr      => stderr_data,
    :exit_code   => exit_code,
    :exit_signal => exit_signal
  }
end

$evm.log(:info, "********************** #{$evm.root['ae_state']} ******************************")

Net::SSH.start($evm.root['deployment_master'], $evm.root['ssh_username'], :paranoid => false, :forward_agent => true, :agent_socket_factory => -> { UNIXSocket.open($evm.root['agent_socket']) }) do |ssh|
  $evm.log(:info, "Starting deployment on master, ip address: #{$evm.root['deployment_master']}")
  begin
    result = ssh_exec!(ssh, "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml -i /usr/share/ansible/openshift-ansible/inventory.yaml")
    unless result[:exit_code] == 0
      $evm.root['automation_task'].message = "FAILED: couldn't execute command ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml -i /usr/share/ansible/openshift-ansible/inventory.yaml. ERROR: #{result[:stderr]}"
      $evm.root['ae_result'] = "error"
    end
    $evm.root['ae_result'] = analyze_ansible_output(result[:stdout]) ? "ok" : "error"
    $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
         "| Message: #{$evm.root['automation_task'].message}")
  rescue StandardError => e
    $evm.log(:info, e)
    $evm.root['ae_result'] = "error"
  end
end

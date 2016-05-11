gem "net-ssh", "=4.0.0.alpha3"
require 'net/ssh'

def ssh_exec!(ssh, command)
  stdout_data, stderr_data = "", ""
  exit_code, exit_signal = nil, nil

  ssh.open_channel do |channel|
    channel.exec("ssh -A -o 'StrictHostKeyChecking no' -t -t #{$evm.root['user']}@#{$evm.root['deployment_master']} " \
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
agent_socket = "/tmp/ssh_manageiq/ssh_manageiq_#{$evm.root['automation_task'].automation_request.options[:attrs][:deployment_id]}"
Net::SSH.start($evm.root['deployment_master'], $evm.root['user'], :paranoid => false, :forward_agent => true, :agent_socket_factory => ->{ UNIXSocket.open(agent_socket) }) do |ssh|
  $evm.log(:info, "Starting deployment on master, ip address: #{$evm.root['deployment_master']}")
  begin
    ssh_exec!(ssh, "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml -i /usr/share/ansible/openshift-ansible/inventory.yaml")
  rescue Exception => e
    $evm.log(:info, e)
  end
end

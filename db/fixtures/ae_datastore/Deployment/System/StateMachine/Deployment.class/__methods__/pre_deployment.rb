require 'net/ssh'

LOCAL_BOOK = 'local_book.yaml'.freeze
COMMANDS = ['yum install ansible -y',
            'yum install openshift-ansible -y',
            'yum install openshift-ansible-playbooks -y',
            'yum install pyOpenSSL -y',
            "mv ~/inventory.yaml /usr/share/ansible/openshift-ansible/"
           ]

def ssh_exec!(ssh, command)
  stdout_data, stderr_data = "", ""
  exit_code, exit_signal = nil, nil

  ssh.open_channel do |channel|
    channel.exec("ssh -o 'StrictHostKeyChecking no' -t -t #{$evm.root['user']}@#{$evm.root['deployment_master']}" \
                     " sudo " + command) do |_, success|
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

def pre_deployment
  $evm.log(:info, "********************** master pre deployment ***************************")
  $evm.root['state'] = "pre_deployment"
  begin
    Net::SSH.start($evm.root['deployment_master'], $evm.root['user'], :paranoid => false, :forward_agent => true,
                   :key_data => $evm.root['private_key']) do |ssh|
      $evm.log(:info, "Connected to deployment master, ip address: #{$evm.root['deployment_master']}")
      system "scp -o 'StrictHostKeyChecking no' inventory.yaml #{$evm.root['user']}@#{$evm.root['deployment_master']}:~/"
      failed_execute = false
      release = ssh.exec!("cat /etc/redhat-release")
      COMMANDS.unshift('yum install epel-release -y') if release.include?("CentOS")
      COMMANDS.each do |cmd|
        result = ssh_exec!(ssh, cmd)
        unless result[:exit_code] == 0
          $evm.root['automation_task'].message = "FAILED: couldn't execute command #{cmd}. ERROR: #{result[:stderr]}"
          $evm.root['ae_result'] = "error"
          failed_execute = true
        end
        break if failed_execute
      end
      unless failed_execute
        $evm.root['ae_result'] = "ok"
        $evm.root['automation_task'].message = "successful pre-deployment"
      end
    end
  rescue
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = "Cannot connect to deployment master " \
                                           "(#{$evm.root['deployment_master']}) via ssh"
  ensure
    $evm.log(:info, "State: #{$evm.root['state']} | Result: #{$evm.root['ae_result']} "\
             "| Message: #{$evm.root['automation_task'].message}")
  end
end

pre_deployment

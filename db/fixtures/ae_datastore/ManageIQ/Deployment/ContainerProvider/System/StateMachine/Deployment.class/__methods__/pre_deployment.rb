gem "net-ssh", "=3.2.0.rc2"
require 'net/ssh'

LOCAL_BOOK = 'local_book.yaml'.freeze
REPO_URL = "https://copr.fedorainfracloud.org/coprs/maxamillion/origin-next/repo/epel-7/maxamillion-origin-next-epel-7.repo".freeze

def handle_rhel_subscriptions(commands)
  commands.unshift( "subscription-manager register --username=#{$evm.root['rhsub_user']}  --password=#{$evm.root['rhsub_pass']}",
                    "subscription-manager repos --disable=\"*\"",
                    "subscription-manager repos --enable=\"rhel-7-server-rh-common-rpms\" --enable=\"rhel-7-server-rpms\" --enable=\"rhel-7-server-extras-rpms\"")
  system({"SSH_AUTH_SOCK" => $evm.root['agent_socket'], "SSH_AGENT_PID" => $evm.root['agent_pid']},"scp -o 'StrictHostKeyChecking no' rhel_subscribe_inventory.yaml #{$evm.root['ssh_username']}@#{$evm.root['deployment_master']}:~/")
  rhel_subscribe_cmd = "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/rhel_subscribe.yml -i "\
                       "/usr/share/ansible/openshift-ansible/rhel_subscribe_inventory.yaml"
  commands.push("sudo mv ~/rhel_subscribe_inventory.yaml /usr/share/ansible/openshift-ansible/", rhel_subscribe_cmd)
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

def pre_deployment
  commands = ['sudo yum install -y ansible-1.9.4',
              'sudo yum install -y openshift-ansible openshift-ansible-playbooks pyOpenSSL',
              "sudo mv ~/inventory.yaml /usr/share/ansible/openshift-ansible/"
              ]
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
  begin
    Net::SSH.start($evm.root['deployment_master'], $evm.root['ssh_username'], :paranoid => false, :forward_agent => true, :agent_socket_factory => ->{ UNIXSocket.open($evm.root['agent_socket']) }) do |ssh|
      $evm.log(:info, "Connected to deployment master, ip address: #{$evm.root['deployment_master']}")
      system({"SSH_AUTH_SOCK" =>  $evm.root['agent_socket'], "SSH_AGENT_PID" =>  $evm.root['agent_pid']}, "scp -o 'StrictHostKeyChecking no' inventory.yaml #{$evm.root['ssh_username']}@#{$evm.root['deployment_master']}:~/")
      failed_execute = false
      release = ssh.exec!("cat /etc/redhat-release")
      if release.include?("CentOS")
        commands.unshift("sudo yum install epel-release -y",
                         "sudo curl -o /etc/yum.repos.d/maxamillion-origin-next-epel-7.repo #{REPO_URL}")
      elsif release.include?("Red Hat Enterprise Linux") &&
            !$evm.root['automation_task'].automation_request.options[:attrs][:containerized]
        ssh.exec!("echo -e \"[temp]\nname=alontemp\nbaseurl=http://download.eng.bos.redhat.com/rcm-guest/puddles/RHAOS/AtomicOpenShift/3.2/arbitrary-yaml/x86_64/os/\nenabled=1\ngpgcheck=0\" > /etc/yum.repos.d/temp.repo")
        # commands = handle_rhel_subscriptions(commands)
      end
      commands.each do |cmd|
        # $evm.log(:info, "runnigng cmd #{cmd}")
        result = ssh_exec!(ssh, cmd)
        if cmd.include?("subscription-manager register") && result[:exit_code] == 0
          pool_id = ssh_exec!(ssh, "subscription-manager list --available --matches=#{$evm.root['rhsub_sku']} --pool-only")[:stdout].split("\n").first.delete("\r")
          ssh_exec!(ssh, "subscription-manager attach --pool=#{pool_id}")
        end
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
  rescue Exception => e
    $evm.log(:info, e)
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = e.message
  ensure
    $evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
             "| Message: #{$evm.root['automation_task'].message}")
  end
end

pre_deployment

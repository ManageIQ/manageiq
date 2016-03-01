require 'net/ssh'

def remove_deployment_master(hosts, master_ip)
  hosts.each do |host|
    if host.include? master_ip
      hosts.delete(host)
    end
  end
  hosts
end

def check_ssh
  $evm.log(:info, "**************** #{$evm.root['ae_state']} ****************")

  deployment_hosts = $evm.root['masters'] + $evm.root['nodes']
  deployment_hosts = remove_deployment_master(deployment_hosts, $evm.root['deployment_master'])

  begin
    Net::SSH.start($evm.root['deployment_master'], $evm.root['user'], :paranoid => false, :forward_agent => true,
                   :key_data => $evm.root['private_key']) do |ssh|
      $evm.log(:info, "Connected to deployment master, ip address: #{$evm.root['deployment_master']}")
      connection_failure = false
      unreachable_hosts = []
      deployment_hosts.each do |host|
        res = ssh.exec!("ssh -o 'StrictHostKeyChecking no' #{$evm.root['user']}@" + host + " echo $?")
        unless res.include? "0\n"
          connection_failure = true
          unreachable_hosts << host
        end
      end
      if connection_failure
        $evm.root['ae_result'] = "error"
        $evm.root['automation_task'].message = "Cannot connect to #{unreachable_hosts.inspect} via ssh"
      else
        $evm.root['ae_result'] = "ok"
        $evm.root['automation_task'].message = "successful ssh to " \
        "#{deployment_hosts.prepend($evm.root['deployment_master']).inspect}"
      end
    end
  rescue
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = "Cannot connect to deployment master " \
    "(#{$evm.root['deployment_master']}) via ssh"
  end
end

check_ssh
$evm.log(:info, "State: #{$evm.root['ae_state']} | Result: #{$evm.root['ae_result']} "\
           "| Message: #{$evm.root['automation_task'].message}")

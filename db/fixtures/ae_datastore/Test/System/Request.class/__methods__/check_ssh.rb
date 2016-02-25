require 'rubygems'
require 'net/ssh'

def check_ssh(deployment_master_ip, user, deployment_ips)
  $evm.root['Phase'] = "check ssh"
  $evm.log(:info, "**************** #{$evm.root["Phase"]} ****************")
  $evm.log(:info, "Connecting to deployment master ipaddress - #{deployment_master_ip}")
  begin
    Net::SSH.start(deployment_master_ip, user, :paranoid => false, :forward_agent => true) do |ssh|
      permission_problem = false
      problematic_ips = []
      deployment_ips.each do |ip|
        res = ssh.exec! ("ssh root@" + deployment_ips[0] + ' pwd')
        if res.include?"Permission"
          permission_problem = true
          problematic_ips << ip
        end
      end
      if permission_problem
        $evm.root['ae_result'] = "error"
        $evm.root['Message'] = "Cannot connect to #{problematic_ips.inspect} via ssh"
      else
        $evm.root['ae_result'] = "ok"
        $evm.root['Message'] = "successful ssh to #{deployment_ips.inspect}"
      end

    end
  rescue
    $evm.root['ae_result'] = "error"
    $evm.root['Message'] = "Cannot connect to #{deployment_master_ip} via ssh"
  end
  $evm.log(:info, "#{$evm.root['Phase']} : #{$evm.root['ae_result']} : #{$evm.root['Message']}")
end

master = $evm.root['automation_task'].automation_request.options[:attrs][:connect_through_master_ip]
masters = $evm.root['automation_task'].automation_request.options[:attrs][:masters_ips]
nodes = $evm.root['automation_task'].automation_request.options[:attrs][:nodes_ips]
user = $evm.root['automation_task'].automation_request.options[:attrs][:user]

check_ssh(master, user, nodes)

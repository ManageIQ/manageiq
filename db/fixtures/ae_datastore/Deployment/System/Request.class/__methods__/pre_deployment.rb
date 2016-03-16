require 'net/ssh'

LOCAL_BOOK = 'local_book.yaml'
COMMANDS = ['yum install git',
            'yum install epel-release',
            'test -d /tmp/openshift-ansible || git clone https://github.com/openshift/openshift-ansible.git /tmp/openshift-ansible',
            'yum install ansible',
            'yum install pyOpenSSL',
            "mv /home/#{$evm.root['user']}/inventory.yaml /tmp/openshift-ansible"
]

def analyze_ansible_output(output)
  result = output.rpartition('PLAY RECAP ********************************************************************').last
  result = result.split(" ")
  passed = true
  result.each do |cell|
    if ((cell.include?("failed") || cell.include?("unreachable")) && (!cell.include?("=0")))
      passed = false
      $evm.root['ae_result'] = "error"
      $evm.root['automation_task'].message = "pre-deployment failed"
      break
    end
  end

  if passed
    $evm.root['automation_task'].message = "successful pre-deployment"
  end
  passed
end

def ssh_exec(cmd, ssh)
  ssh.exec!("ssh -o 'StrictHostKeyChecking no' -t -t #{$evm.root['user']}@#{$evm.root['deployment_master']} sudo " + cmd)
end

def pre_deployment()
  $evm.log(:info, "********************** master pre deployment ***************************")
  $evm.root['state'] = "pre_deployment"
  begin
    Net::SSH.start($evm.root['deployment_master'], $evm.root['user'], :paranoid => false, :forward_agent => true,
                   :keys => [$evm.root['ssh_key_path']]) do |ssh|
      $evm.log(:info, "Connected to deployment master, ip address: #{$evm.root['deployment_master']}")
      system "scp -o 'StrictHostKeyChecking no' inventory.yaml #{$evm.root['user']}@" + $evm.root['deployment_master'] + ":/home/#{$evm.root['user']}"
      COMMANDS.each do |cmd|
        res = ssh_exec(cmd, ssh)
      end
      # TODO: verify ssh cmd results
    end
  rescue
    $evm.root['ae_result'] = "error"
    $evm.root['automation_task'].message = "Cannot connect to deployment master " \
    "(#{$evm.root['deployment_master']}) via ssh"
  end
end

pre_deployment
$evm.log(:info, "State: #{$evm.root['state']} | Result: #{$evm.root['ae_result']} "\
         "| Message: #{$evm.root['automation_task'].message}")
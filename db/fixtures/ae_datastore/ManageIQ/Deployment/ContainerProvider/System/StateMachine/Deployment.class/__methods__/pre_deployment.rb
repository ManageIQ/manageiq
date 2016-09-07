LOCAL_BOOK = 'local_book.yaml'.freeze
REPO_URL   = "https://copr.fedorainfracloud.org/coprs/maxamillion/origin-next/repo/epel-7/maxamillion-origin-next-epel-7.repo".freeze
INVENTORY_FILE = 'inventory.yaml'.freeze
RHEL_SUBSCRIBE_INVENTORY = 'rhel_subscribe_inventory.yaml'.freeze

def pre_deployment(deployment)
  $evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
  $evm.root['inventory'] = $evm.root['container_deployment'].generate_ansible_yaml
  $evm.root['rhel_subscribe_inventory'] = $evm.root['container_deployment'].generate_ansible_inventory_for_subscription
  create_ansible_inventory_file
  release = deployment.perform_agent_commands(["sudo cat /etc/redhat-release"])[:stdout]
  create_ansible_inventory_file(true) if release.include?("Red Hat Enterprise Linux")
  deployment.perform_scp("inventory.yaml", "inventory.yaml")
  commands = ['sudo yum install -y ansible-1.9.4',
              'sudo yum install -y openshift-ansible openshift-ansible-playbooks pyOpenSSL',
              "sudo mv ~/inventory.yaml /usr/share/ansible/openshift-ansible/",
              "sudo yum install -y atomic-openshift-utils"]
  if release.include?("CentOS")
    commands.unshift("sudo yum install epel-release -y",
                     "sudo curl -o /etc/yum.repos.d/maxamillion-origin-next-epel-7.repo #{REPO_URL}",
                     "sudo yum install centos-release-paas-common centos-release-openshift-origin -y")
  elsif release.include?("Red Hat Enterprise Linux")
    deployment.subscribe_deployment_master
  end
  deployment.perform_agent_commands(commands)
  if release.include?("Red Hat Enterprise Linux") && deployment.nodes_subscription_needed?
    deployment.perform_scp("rhel_subscribe_inventory.yaml", "rhel_subscribe_inventory.yaml")
    deployment.subscribe_cluster
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
  else
    $evm.root['ae_result']               = "ok"
    $evm.root['automation_task'].message = "#{$evm.root['ae_state']} was finished successfully"
  end
end

def create_ansible_inventory_file(subscribe = false)
  if subscribe
    template = $evm.root['rhel_subscribe_inventory']
    inv_file_path = RHEL_SUBSCRIBE_INVENTORY
  else
    template = $evm.root['inventory']
    inv_file_path = INVENTORY_FILE
  end
  $evm.log(:info, "creating #{inv_file_path}")
  File.write(inv_file_path, template)
  $evm.root['ae_result'] = "ok"
  $evm.root['automation_task'].message = "successfully created #{inv_file_path}"
end

begin
  $evm.root['container_deployment'] ||= $evm.vmdb(:container_deployment).find(
    $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id]
  )
  deployment = $evm.root['container_deployment']
  if deployment.playbook_running?
    result = deployment.subscribe_cluster
    if result[:finished]
      $evm.root['ae_result'] = deployment.analyze_ansible_output(result[:stdout]) ? "ok" : "error"
    else
      $evm.log(:info, "*********  pre-deployment playbook is runing waiting for it to finish ************")
      $evm.root['ae_result']         = 'retry'
      $evm.root['ae_retry_interval'] = '1.minute'
    end
  else
    pre_deployment(deployment)
    if File.exist?(INVENTORY_FILE)
      $evm.log(:info, "deleting #{INVENTORY_FILE}")
      FileUtils.rm(INVENTORY_FILE)
    end
    if File.exist?(RHEL_SUBSCRIBE_INVENTORY)
      $evm.log(:info, "deleting #{RHEL_SUBSCRIBE_INVENTORY}")
      FileUtils.rm(RHEL_SUBSCRIBE_INVENTORY)
    end
  end
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = "Error: #{err.message}"
  exit MIQ_ERROR
end

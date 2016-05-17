gem "net-ssh", "=4.0.0.alpha4"
require 'net/ssh'

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

COMMANDS = [
  "subscription-manager register --username=#{$evm.root['rhsub_user']}  --password=#{$evm.root['rhsub_pass']}",
  "subscription-manager repos --disable=\"*\"",
  "subscription-manager repos --enable=\"rhel-7-server-rh-common-rpms\" --enable=\"rhel-7-server-rpms\" --enable=\"rhel-7-server-extras-rpms\" --enable=\"rhel-7-server-ose-3.2-rpms\""
].freeze

def find_vm_by_tag(tag)
  tag = "/managed/deploy/#{tag}_#{$evm.root['automation_task'][:id]}"
  $evm.vmdb(:vm).find_tagged_with(:any => tag, :ns => "*")
end

def assign_vms_to_deployment_nodes(masters, nodes)
  deployment = $evm.vmdb(:container_deployment).find(
    $evm.root['automation_task'].automation_request.options[:attrs][:deployment_id])
  deployment_master = masters.first
  deployment.assign_container_deployment_node(deployment_master.id, "deployment_master")
  $evm.root['deployment_master'] = deployment_master.hardware.ipaddresses.last
  masters.each do |master|
    deployment.assign_container_deployment_node(master.id, "master") unless master == deployment_master
  end
  nodes.each do |node|
    deployment.assign_container_deployment_node(node.id, "node")
  end
  $evm.root['inventory'] = deployment.regenerate_ansible_inventory
  $evm.root['rhel_subscribe_inventory'] =  deployment.regenerate_ansible__subscription_inventory
end

def missing_subscription_fields?
  $evm.root['rhsub_user'].nil? || $evm.root['rhsub_pass'].nil? || $evm.root['rhsub_sku'].nil?
end

def subscribe_if_rhel
  Net::SSH.start($evm.root['deployment_master'], $evm.root['ssh_username'], :paranoid => false, :forward_agent => true,
                 :key_data                                                            => $evm.root['ssh_private_key']) do |ssh|
    $evm.log(:info, "Connected to deployment master , ip address: #{$evm.root['deployment_master']} Checking if RHEL")
    release = ssh.exec!("cat /etc/redhat-release")
    if release.include?("Red Hat Enterprise Linux") && missing_subscription_fields?
      $evm.root['ae_result']               = "error"
      $evm.root['automation_task'].message = "Missing credentials for rhn subscription"
    elsif release.include?("Red Hat Enterprise Linux")
      $evm.log(:info, "starting RHN subscribing")
      failed_execute = false
      COMMANDS.each_with_index do |cmd, index|
        result = ssh_exec!(ssh, cmd)
        unless result[:exit_code] == 0
          $evm.root['automation_task'].message = "FAILED: couldn't execute command #{cmd}. ERROR: #{result[:stderr]}"
          $evm.root['ae_result']               = "error"
          failed_execute                       = true
        end
        if index == 0
          pool_id = ssh_exec!(ssh, "subscription-manager list --available --matches=#{$evm.root['rhsub_sku']} --pool-only")[:stdout].split("\n").first.delete("\r")
          ssh_exec!(ssh, "subscription-manager attach --pool=#{pool_id}")
        end
        break if failed_execute
      end
      unless failed_execute
        $evm.root['ae_result']               = "ok"
        $evm.root['automation_task'].message = "successful post-provision"
      else
        $evm.root['ae_result'] = "error"
        $evm.root['automation_task'].message = "Failed executing RHEL subscirbe"
      end
    end
  end
rescue Exception => e
  $evm.log(:info, e)
  $evm.root['ae_result']               = "error"
  $evm.root['automation_task'].message = e.message
ensure
  $evm.log(:info, "State: #{$evm.root['state']} | Result: #{$evm.root['ae_result']} "\
           "| Message: #{$evm.root['automation_task'].message}")
end

def extract_ips(vms)
  ips = []
  vms.each do |vm|
    ips << vm.hardware.ipaddresses.last unless vm.hardware.ipaddresses.empty?
  end
  ips
end

def wait_for_ip_adresses
  $evm.root['state'] = "post_provision"
  $evm.root['automation_task'].message = "Trying to recieve ips"
  tagged_vms_masters = find_vm_by_tag("master")
  tagged_vms_nodes = find_vm_by_tag("node")
  masters_ips = extract_ips(tagged_vms_masters)
  nodes_ips = extract_ips(tagged_vms_nodes)
  if nodes_ips.count + masters_ips.count == tagged_vms_masters.count + tagged_vms_nodes.count
    assign_vms_to_deployment_nodes(tagged_vms_masters, tagged_vms_nodes)
    masters_ips.delete($evm.root['deployment_master'])
    $evm.root['masters'] = masters_ips
    $evm.root['nodes'] = nodes_ips
    subscribe_if_rhel
    $evm.root['ae_result'] = 'ok'
  else
    $evm.log(:info, "*********  Post-Provision waiting on ips ************")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '2.minute'
    refresh_provider
  end
end

def refresh_provider
  deploy_on_provider = $evm.vmdb(:ext_management_system).find($evm.root['automation_task'].automation_request.options[:attrs][:provision_provider_id])
  deploy_on_provider.refresh
end

$evm.log(:info, "********************** #{$evm.root['ae_state']} ***************************")
wait_for_ip_adresses

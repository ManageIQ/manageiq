class ContainerDeployment
  module Automate
    extend ActiveSupport::Concern
    RHEL_SUBSCRIPTION_FILE_NAME = "rhel_subscribe_inventory.yaml".freeze
    SUBSCRIPTION_REPOS = ["rhel-7-server-rh-common-rpms", "rhel-7-server-rpms", "rhel-7-server-extras-rpms", "rhel-7-server-ose-3.2-rpms"].freeze
    ANSIBLE_LOG = "/tmp/ansible.log".freeze
    ANSIBLE_ERROR_LOG = "/tmp/openshift-ansible.log".freeze
    INVENTORIES_PATH = "/usr/share/ansible/openshift-ansible/".freeze
    SSH_AGENT_PATH = "/tmp/ssh_manageiq/".freeze

    def run_playbook_command(cmd)
      ip = roles_addresses("deployment_master")
      username = ssh_user
      result = {:finished => false}
      @ssh ||= LinuxAdmin::SSH.new(ip, username, ssh_auth.auth_key)
      ansible_process_pid = ansible_pid
      if ansible_process_pid
        process_running = @ssh.perform_commands(["sudo kill -0 #{ansible_process_pid}"])[:stdout]
        unless process_running.empty?
          result[:finished] = true
          result[:stdout] = @ssh.perform_commands(["sudo cat /tmp/ansible.log"])[:stdout]
          stop_agent
        end
      else
        start_playbook_command(username, cmd)
      end
      result
    end

    def start_playbook_command(username, cmd)
      pid, socket = create_agent(username)
      @ssh.perform_commands(["sudo rm -f #{ANSIBLE_ERROR_LOG} #{ANSIBLE_LOG}"])
      @ssh.perform_commands(["SSH_AUTH_SOCK=#{socket} nohup sudo -b -E #{cmd} 1> #{ANSIBLE_LOG} 2> #{ANSIBLE_ERROR_LOG} < /dev/null"])
      ansible_process_pid = @ssh.perform_commands(["sudo pgrep -f 'sudo -b -E'"])[:stdout].split("\r").first
      customize(:ansible_pid => ansible_process_pid, :agent_pid => pid, :agent_socket => socket)
    end

    def create_agent(username)
      output = @ssh.perform_commands { |ssh| ssh.exec!("ssh-agent -a ssh_manageiq_#{id}") }
      vars = {}
      output.scan(/^(\w+)=([^;\n]+)/) { |k, v| vars[k] = v }
      socket, pid = vars.values_at('SSH_AUTH_SOCK', 'SSH_AGENT_PID')
      socket = "/#{username}/#{socket}"
      socket = "/home#{socket}" if username != "root"
      @ssh.perform_commands(["SSH_AUTH_SOCK=#{socket} SSH_AGENT_PID=#{pid} ssh-add -"], nil, ssh_auth.auth_key)
      [pid, socket]
    end

    def stop_agent
      pid =  agent_pid
      socket = agent_socket
      @ssh.perform_commands(["SSH_AGENT_PID=#{pid} ssh-agent -k &> /dev/null"])
      @ssh.perform_commands(["sudo rm -f #{socket}"])
      customize(:ansible_pid => nil, :agent_pid => nil, :agent_socket => nil)
    end

    def analyze_ansible_output(output)
      if output.blank?
        return false
      end
      results = output.rpartition('PLAY RECAP ********************************************************************').last
      results = results.split("\r\n")
      results.shift
      results.detect { |x| !x.include?("unreachable=0") || !x.include?("failed=0") }.blank?
    end

    def provision_vms_status
      finished = provision_tasks.where(:request_state => 'finished', :status => 'Ok').count == provision_tasks.count
      fail = provision_tasks.where(:request_state => 'finished', :status => 'Error').count > 0
      [finished, fail]
    end

    def find_vm_by_type(type)
      requests = MiqRequest.where(:id => automation_task.miq_request.options["#{type}_request_ids"])
      requests.collect(&:vms).flatten
    end

    def assign_container_deployment_nodes
      tagged_vms_masters = find_vm_by_type("master")
      tagged_vms_nodes = find_vm_by_type("node")
      tagged_vms_masters.each do |master|
        assign_container_deployment_node(master.id, "master")
      end
      tagged_vms_nodes.each do |node|
        assign_container_deployment_node(node.id, "node")
      end
    end

    def assign_container_deployment_node(vm_id, role)
      container_nodes_by_role(role).each do |deployment_node|
        next unless deployment_node.vm_id.nil?
        deployment_node.vm_id = vm_id
        deployment_node.save!
      end
    end

    def provisioned_ips_set?
      tagged_vms_masters = find_vm_by_type("master")
      tagged_vms_nodes = find_vm_by_type("node")
      masters_ips = tagged_vms_masters.collect do |vm|
        vm.ipaddresses.last
      end.compact
      nodes_ips = tagged_vms_nodes.collect do |vm|
        vm.ipaddresses.last
      end.compact
      return true if nodes_ips.count + masters_ips.count == tagged_vms_masters.count + tagged_vms_nodes.count
      false
    end

    def check_connection
      deployment_host_ip = roles_addresses("deployment_master")
      username = ssh_user
      agent = LinuxAdmin::SSHAgent.new(ssh_auth.auth_key, "#{SSH_AGENT_PATH}ssh_manageiq_#{id}")
      nodes_ips = container_deployment_nodes.collect(&:node_address)
      nodes_ips.delete(deployment_host_ip)
      @ssh ||= LinuxAdmin::SSH.new(deployment_host_ip, username, ssh_auth.auth_key)
      raise StandardError, "couldn't connect to : #{deployment_host_ip}" if @ssh.perform_commands(["echo 0"])[:stdout].exclude?("0\r\n")
      return true if nodes_ips.blank?
      success, unreachable_ips = agent.with_service do |socket|
        unreachable_ips = nodes_ips.select do |sub_ip|
          @ssh.perform_commands(["sudo -E ssh -o 'StrictHostKeyChecking no' #{username}@#{sub_ip} echo 0"], socket)[:stdout].exclude?("0\r\n")
        end
        [unreachable_ips.empty?, unreachable_ips]
      end
      raise StandardError, "couldn't connect to : #{unreachable_ips.join(',')}" unless success
      true
    end

    def subscribe_deployment_master
      rhsub_user = rhsm_auth.userid
      rhsub_pass = rhsm_auth.password
      rhsm_sku = rhsm_auth.rhsm_sku
      perform_agent_commands(["sudo subscription-manager register --username='#{rhsub_user}' --password='#{rhsub_pass}'"])
      pool_cmdret = perform_agent_commands(["sudo subscription-manager list --available --matches='#{rhsm_sku}' --pool-only"])
      pool_id = pool_cmdret[:stdout].split("\n").first.to_s.strip
      perform_agent_commands(["sudo subscription-manager attach --pool='#{pool_id}'"]) unless pool_id.blank?
      enabled_repos_cmdret = perform_agent_commands(['sudo subscription-manager repos --disable="*"',
                                                     "sudo subscription-manager repos --enable=#{SUBSCRIPTION_REPOS.join(" --enable=")}",
                                                     "sudo subscription-manager repos --list-enabled"])
      enabled_repos = enabled_repos_cmdret[:stdout].split(" ").to_a.map(&:strip).reject(&:empty?)
      missing_repos = SUBSCRIPTION_REPOS - enabled_repos
      raise StandardError, "couldn't register to following repos : #{missing_repos.join(',')} with SKU : #{rhsm_sku}" unless missing_repos.empty?
    end

    def subscribe_cluster
      perform_agent_commands(["sudo mv ~/#{RHEL_SUBSCRIPTION_FILE_NAME} #{INVENTORIES_PATH}"])
      run_playbook_command("ansible-playbook #{INVENTORIES_PATH}playbooks/byo/rhel_subscribe.yml -i "\
                           "#{INVENTORIES_PATH}#{RHEL_SUBSCRIPTION_FILE_NAME} 1> #{ANSIBLE_LOG} 2> #{ANSIBLE_ERROR_LOG} < /dev/null")
    end

    def provision_tasks
      automation_task.automation_request.reload
      return [] unless automation_task.automation_request.options["master_request_ids"]
      ids = automation_task.miq_request.options["master_request_ids"] + automation_task.miq_request.options["node_request_ids"]
      MiqRequest.where(:id => ids)
    end

    def provision_started?
      provision_tasks.count > 0
    end

    def nodes_subscription_needed?
      container_deployment_nodes.count > 1
    end

    def agent_exists?
      agent_pid
    end

    def ssh_user
      ssh_auth.userid
    end

    def add_automation_task(task)
      send(:update_attributes!, :automation_task_id => task.id)
    end

    def customize(options = {})
      self.customizations = {:agent => {}} if customizations.empty?
      customizations[:agent].merge!(options)
      save!
    end

    def perform_scp(local_path, remote_path)
      ip = roles_addresses("deployment_master")
      username = ssh_user
      Net::SCP.upload!(ip, username, local_path, remote_path, :ssh => {:key_data => ssh_auth.auth_key})
    end

    def perform_agent_commands(commands = [])
      @ssh ||= begin
        ip = roles_addresses("deployment_master")
        username = ssh_user
        LinuxAdmin::SSH.new(ip, username, ssh_auth.auth_key)
      end
      @ssh.perform_commands(commands)
    end

    def playbook_running?
      agent_pid.present?
    end

    def agent_pid
      customizations.fetch_path(:agent, :agent_pid)
    end

    def agent_socket
      customizations.fetch_path(:agent, :agent_socket)
    end

    def ansible_pid
      customizations.fetch_path(:agent, :ansible_pid)
    end
  end
end


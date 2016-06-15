require 'net/scp'

module MiqAeMethodService
  class MiqAeServiceContainerDeployment < MiqAeServiceModelBase
    expose :container_deployment_nodes, :association => true
    expose :deployed_ems, :association => true
    expose :deployed_on_ems, :association => true
    expose :automation_task, :association => true
    expose :roles_addresses
    expose :container_nodes_by_role
    expose :ssh_auth
    expose :rhsm_auth

    def assign_container_deployment_node(vm_id, role)
      container_nodes_by_role(role).each do |deployment_node|
        next unless deployment_node.vm_id.nil?
        deployment_node.add_vm vm_id
      end
    end

    def subscribe_deployment_master(deployment_master, user)
      rhsub_user, rhsub_pass, rhsm_sku = rhsm_creds
      subscribed = perform_agent_commands(deployment_master, user, ["sudo subscription-manager register --username='#{rhsub_user}'  --password='#{rhsub_pass}'"])[:stdout]
      unless subscribed.include? "This system is already registered"
        pool_id = perform_agent_commands(deployment_master, user, ["sudo subscription-manager list --available --matches=#{rhsm_sku} --pool-only"])[:stdout].split("\n").first.delete("\r")
        perform_agent_commands(deployment_master, user, ["sudo subscription-manager attach --pool=#{pool_id}",
                                                         "sudo subscription-manager repos --disable=\"*\"",
                                                         "sudo subscription-manager repos --enable=\"rhel-7-server-rh-common-rpms\" --enable=\"rhel-7-server-rpms\" --enable=\"rhel-7-server-extras-rpms\" --enable=\"rhel-7-server-ose-3.2-rpms\""
                                                ])
      end
      if subscription_needed?
        perform_scp(deployment_master, user, "rhel_subscribe_inventory.yaml", "rhel_subscribe_inventory.yaml")
      end
    end

    def subscribe_cluster(deployment_master, user)
      perform_agent_commands(deployment_master, user, ["sudo mv ~/rhel_subscribe_inventory.yaml /usr/share/ansible/openshift-ansible/"])
      run_playbook_command(deployment_master, user, "ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/byo/rhel_subscribe.yml -i "\
                         "/usr/share/ansible/openshift-ansible/rhel_subscribe_inventory.yaml 1> /tmp/ansible.log 2> /tmp/openshift-ansible.log.2 < /dev/null")
    end

    def subscription_needed?
      container_deployment_nodes.count > 1
    end

    def rhsm_creds
      [rhsm_auth.userid, rhsm_auth.password, rhsm_auth.rhsm_sku]
    end

    def ssh_user
      ssh_auth.userid
    end

    def add_deployment_provider(options)
      object_send(:add_deployment_provider, options)
    end

    def regenerate_ansible_inventory
      object_send(:generate_ansible_yaml)
    end

    def regenerate_ansible_subscription_inventory
      object_send(:generate_ansible_inventory_for_subscription)
    end

    def add_automation_task(task)
      ar_method do
        @object.automation_task = AutomationTask.find_by_id(task.id)
        @object.save!
      end
    end

    def customize(options = {})
      ar_method do
        if @object.customizations.empty?
          @object.customizations = {:agent => {}}
        end
        options.each do |key, val|
          @object.customizations[:agent][key] = val
        end
        @object.save!
      end
    end

    def perform_scp(ip, username, local_path, remote_path)
      Net::SCP.upload!(ip,
                       username,
                       local_path,
                       remote_path,
                       :ssh => {:key_data => ssh_auth.auth_key})
    end

    def perform_agent_commands(ip, username, commands = [])
      ssh = LinuxAdmin::SSH.new(ip, username, ssh_auth.auth_key)
      ssh.perform_commands(commands)
    end

    def check_connection(deployment_host_ip, username, nodes_ips)
      agent = LinuxAdmin::SSHAgent.new(ssh_auth.auth_key, "/tmp/ssh_manageiq/ssh_manageiq_#{id}")
      success, unreachable_ips = agent.with_service do |socket|
        ssh = LinuxAdmin::SSH.new(deployment_host_ip, username)
        unreachable_ips = nodes_ips.select do |sub_ip|
          !ssh.perform_commands(["sudo -E ssh -o 'StrictHostKeyChecking no' #{username}@#{sub_ip} echo $?"], socket)[:stdout].include?("0\r\n")
        end
        [unreachable_ips.empty?, unreachable_ips]
      end
      unless success
        raise StandardError, "couldn't connect to : #{unreachable_ips.join(',')}"
      end
      success
    end

    def playbook_running?
      pid = ar_method do
        @object.customizations[:agent][:ansible_pid] if @object.customizations[:agent]
      end
      !pid.nil?
    end

    def run_playbook_command(ip, username, cmd)
      result = {:finished => false}
      ansible_pid = ar_method do
        @object.customizations[:agent][:ansible_pid] if @object.customizations[:agent]
      end
      ssh = LinuxAdmin::SSH.new(ip, username, ssh_auth.auth_key)
      if ansible_pid
        process_running = ssh.perform_commands(["sudo kill -0 #{ansible_pid}"])[:stdout]
        unless process_running.empty?
          result[:finished] = true
          result[:stdout] = ssh.perform_commands(["sudo cat /tmp/ansible.log"])[:stdout]
          stop_agent(ssh)
        end
      else
        pid, socket = create_agent(ssh, username)
        ssh.perform_commands(["sudo rm -f /tmp/*ansible.log*"])
        ssh.perform_commands(["SSH_AUTH_SOCK=#{socket} nohup sudo -b -E #{cmd}"])
        ansible_pid = ssh.perform_commands(["sudo pgrep -f 'sudo -b -E'"])[:stdout].split("\r").first
        customize(:ansible_pid => ansible_pid, :agent_pid => pid, :agent_socket => socket)
      end
      result
    end

    def agent_exists?
      ar_method do
        @object.customizations[:agent][:agent_pid] if @object.customizations[:agent]
      end
    end

    def create_agent(ssh, username)
      output = ssh.perform_commands(["ssh-agent -a ssh_manageiq_#{id}"])[:stdout]
      socket = output.split('=')[1].split(' ')[0].chop
      socket = "/#{username}/#{socket}"
      socket = "/home#{socket}" if username != "root"
      pid = output.split('=')[2].split(' ')[0].chop
      ssh.perform_commands(["SSH_AUTH_SOCK=#{socket} SSH_AGENT_PID=#{pid} ssh-add -"], nil, ssh_auth.auth_key)
      [pid, socket]
    end

    def stop_agent(ssh)
      pid =  ar_method do
        @object.customizations[:agent][:agent_pid]
      end
      socket = ar_method do
        @object.customizations[:agent][:agent_socket]
      end
      ssh.perform_commands(["SSH_AGENT_PID=#{pid} ssh-agent -k &> /dev/null"])
      ssh.perform_commands(["sudo rm -f #{socket}"])
      customize(:ansible_pid => nil, :agent_pid => nil, :agent_socket => nil)
    end

    def analyze_ansible_output(output)
      if output.empty?
        return false
      end
      results = output.rpartition('PLAY RECAP ********************************************************************').last
      results = results.split("\r\n")
      results.shift
      results.detect { |x| !x.include?("unreachable=0") || !x.include?("failed=0") }.blank?
    end
  end
end

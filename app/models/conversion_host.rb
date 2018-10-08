class ConversionHost < ApplicationRecord
  require 'net/ssh'
  require 'net/sftp'

  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :resource, :polymorphic => true
  has_many :service_template_transformation_plan_tasks, :dependent => :nullify
  has_many :active_tasks, -> { where(:state => 'active') }, :class_name => ServiceTemplateTransformationPlanTask, :inverse_of => :conversion_host

  # To be eligible, a conversion host must have the following properties
  #  - A transport mechanism is configured for source (set by 3rd party)
  #  - Credentials are set on the resource and SSH connection works
  #  - The number of concurrent tasks has not reached the limit
  def eligible?
    source_transport_method.present? && check_ssh_connection && check_concurrent_tasks
  end

  def check_concurrent_tasks
    max_tasks = max_concurrent_tasks || Settings.transformation.limits.max_concurrent_tasks_per_host
    active_tasks.size < max_tasks
  end

  def check_ssh_connection(remember_host = false)
    ssh_session({:remember_host => remember_host})
    true
  rescue => e
    false
  end

  def source_transport_method
    return 'vddk' if vddk_transport_supported
    return 'ssh' if ssh_transport_supported
  end

  def ipaddress(family = nil)
    ips = ipaddresses
    return ips.first unless %w(ipv4 ipv6).include?(family)
    ips.select { |ip| IPAddr.new(ip).send("#{family}?") }.first
  end 

  def run_conversion(conversion_options)
    res = remote_command('/usr/bin/virt-v2v-wrapper.py', conversion_options.to_json)
    raise "Starting conversion failed with error: #{res[:stderr]}" unless res[:rc].zero?
    res[:stdout]
  end

  def kill_process(pid, signal = 'TERM')
    res = remote_command("/bin/kill -s #{signal} #{pid}")
    res[:rc].zero?
  end

  def get_conversion_state(state_file)
    JSON.parse(download_file(state_file))
  end

  def get_conversion_log(path)
    download_file(path)
  end 

  def check_conversion_host_role
    install_conversion_host_module
    playbook = "/usr/share/doc/ovirt-ansible-v2v-conversion-host-1.2.0/examples/conversion_host_check.yml"
    extra_vars = { :v2v_manageiq_conversion_host_check => true }
    res = ansible_playbook(playbook, extra_vars)
    status = result[:rc].zero? ? 'enabled' : 'disabled'
    tag_resource(status)
  end

  def enable_conversion_host_role
    install_conversion_host_module
    playbook = "/usr/share/doc/ovirt-ansible-v2v-conversion-host-1.2.0/examples/conversion_host_enable.yml"
    extra_vars = {
      :v2v_vddk_package_name => "VMware-vix-disklib-stable.tar.gz",
      :v2v_vddk_package_url  => "http://#{resource.ext_management_system.hostname}/vddk/VMware-vix-disklib-stable.tar.gz"
    }
    res = ansible_playbook(playbook, extra_vars)
    status = result[:rc].zero? ? 'enabled' : 'disabled'
    tag_resource(status)
  end

  def disable_conversion_host_role
    install_conversion_host_module
    playbook = "/usr/share/doc/ovirt-ansible-v2v-conversion-host-1.2.0/examples/conversion_host_disable.yml"
    extra_vars = {}
    res = ansible_playbook(playbook, extra_vars)
    status = result[:rc].zero? ? 'disabled' : 'enabled'
    tag_resource(status)
  end

  private

  def ipaddresses
    resource.ipaddresses.unshift(address).unshift(resource.try(:ipaddress)).reject(&:blank?)
  end 

  def check_resource_credentials(fatal = false, extra_msg = nil)
    success = send("check_resource_credentials_#{resource.ext_management_system.emstype}")
    if !success and fatal
      msg = "Credential not found for #{resource.name}."
      msg += " #{extra_msg}" unless extra_msg.blank?
      _log.error(:msg)
      raise MiqException::Error, msg
    end
    success
  end

  def check_resource_credentials_rhevm
    !(resource.authentication_userid.nil? || resource.authentication_password.nil?)
  end

  def check_resource_credentials_openstack
    ssh_authentications = resource.ext_management_system.authentications
                                  .where(:authtype => 'ssh_keypair')
                                  .where.not(:userid => nil, :auth_key => nil)
    !ssh_authentications.empty?
  end

  def ssh_session(ssh_session_options = {})
    check_resource_credentials(true, "SSH connection aborted.") 
    first_try = true

    Net::SSH.start(*ssh_start_args) do |ssh|
      yield(ssh)
    end
  rescue Net::SSH::HostKeyMismatch => e
    if ssh_session_options[:remember_host] && first_try
      first_try = false
      e.remember_host!
      retry
    else
      raise e
    end 
  end 

  def ssh_start_args
    send("ssh_start_args_#{resource.type.gsub('::', '_').downcase}")
  end

  def ssh_start_args_manageiq_providers_redhat_inframanager_host
    [ ipaddress, resource.authentication_userid, { :password => resource.authentication_password }]
  end 

  def ssh_start_args_manageiq_providers_openstack_cloudmanager_vm
    authentication = resource.ext_management_system.authentications
                             .where(:authtype => 'ssh_keypair')
                             .where.not(:userid => nil, :auth_key => nil)
                             .first
    [ ipaddress, authentication.userid, { :key_data => authentication.auth_key, :keys_only => true, :passwordless_sudo => true }]
  end

  def file_exists?(path)
    ssh_session do |ssh|
      ssh.sftp.stat!(path) do |response|
        response.ok?
      end
    end
  rescue Net::SFTP::Exception => e
      _log.error("Existence check of #{source} failed with error: #{e.message}")
      raise e
  end

  def download_file(source, destination = nil)
    ssh_session do |ssh|
      ssh.sftp.download!(source, destination)
    end
  rescue Net::SFTP::Exception => e
      _log.error("Download of #{source} failed with error: #{e.message}")
      raise e
  end

  def remote_command(command, stdin = nil, run_as = nil)
    require "net/ssh"
    command = "sudo -u #{run_as} #{command}" unless run_as.nil?
    rc, stdout, stderr, exit_code = nil, '', ''
    begin
      ssh_session do |ssh|
        ssh.open_channel do |channel|
          channel.request_pty unless run_as.nil?
          channel.exec(command) do |ch, exec_success|
            raise "Could not execute command '#{command}'" unless exec_success
            ch.on_data { |_, data| stdout += data.to_s }
            ch.on_extended_data { |_, data| stderr += data.to_s }
            ch.on_request("exit-status") { |_, data| rc = data.read_long }
            unless stdin.nil?
              ch.send_data(stdin)
              ch.eof!
            end
          end
          channel.wait
        end
      end
    rescue Net::SSH::Exception => e
      _log.error("Execution of '#{command}' on #{resource.name} has failed with error: #{e.message} ")
      raise e
    end
    { :rc => return_code, :stdout => stdout, :stderr => stderr }
  end

  def ansible_playbook(playbook, extra_vars)
    command = "ansible-playbook -i #{host.name}, #{playbook}"
    extra_vars.each { |k, v| command += " -e '#{k}=#{v}'" }
    remote_command(command)
  end

  def install_conversion_host_module
    res = remote_command("yum install -y ovirt-ansible-v2v-conversion-host")
    raise "Ansible module installation failed with error: #{res[:stderr]}" unless res[:rc].zero?
  end

  def tag_resource(status)
    send("tag_resource_as_#{status}")
  end

  def tag_resource_as_enabled
    resource.tag_add('v2v_transformation_host/true')
    resource.tag_add('v2v_transformation_method/vddk')
  end

  def tag_resource_as_disable
    resource.tag_add('v2v_transformation_host/false')
    resource.tag_remove('v2v_transformation_method/vddk')
  end
end

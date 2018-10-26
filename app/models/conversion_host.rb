class ConversionHost < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :resource, :polymorphic => true
  has_many :service_template_transformation_plan_tasks, :dependent => :nullify
  has_many :active_tasks, -> { where(:state => 'active') }, :class_name => ServiceTemplateTransformationPlanTask, :inverse_of => :conversion_host
  delegate :ext_management_system, :hostname, :ems_ref, :to => :resource, :allow_nil => true

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

  def check_ssh_connection
    connect_ssh { |ssu| ssu.shell_exec('uname -a') }
    true
  rescue => e
    false
  end

  def source_transport_method
    return 'vddk' if vddk_transport_supported
    return 'ssh' if ssh_transport_supported
  end

  def ipaddress(family = 'ipv4')
    return address if address && IPAddr.new(address).send("#{family}?")
    resource.ipaddresses.detect { |ip| IPAddr.new(ip).send("#{family}?") }
  end 

  def run_conversion(conversion_options)
    result = connect_ssh { |ssu| ssu.shell_exec('/usr/bin/virt-v2v-wrapper.py', nil, nil, conversion_options.to_json) }
    JSON.parse(result)
  rescue => e
    raise "Starting conversion failed on '#{resource.name}' with [#{e.class}: #{e}]"
  end

  def kill_process(pid, signal = 'TERM')
    connect_ssh { |ssu| ssu.shell_exec("/bin/kill -s #{signal} #{pid}") }
    true
  rescue
    false
  end

  def get_conversion_state(path)
    json_state = connect_ssh { |ssu| ssu.get_file(path, nil) }
    JSON.parse(json_state)
  rescue => e
    raise "Could not get state file '#{path}' from '#{resource.name}' with [#{e.class}: #{e}"
  end

  def get_conversion_log(path)
    connect_ssh { |ssu| ssu.get_file(path, nil) }
  rescue => e
    raise "Could not get conversion log '#{path}' from '#{resource.name}' with [#{e.class}: #{e}"
  end 

  def check_conversion_host_role
    install_conversion_host_module
    playbook = "/usr/share/ovirt-ansible-v2v-conversion-host/playbooks/conversion_host_check.yml"
    extra_vars = { :v2v_manageiq_conversion_host_check => true }
    ansible_playbook(playbook, extra_vars)
    tag_resource_as('enabled')
  rescue
    tag_resource_as('disabled')
  end

  def enable_conversion_host_role
    install_conversion_host_module
    playbook = "/usr/share/ovirt-ansible-v2v-conversion-host/playbooks/conversion_host_enable.yml"
    extra_vars = {
      :v2v_vddk_package_name => "VMware-vix-disklib-stable.tar.gz",
      :v2v_vddk_package_url  => "http://#{resource.ext_management_system.hostname}/vddk/VMware-vix-disklib-stable.tar.gz"
    }
    ansible_playbook(playbook, extra_vars)
  ensure
    check_conversion_host_role
  end

  def disable_conversion_host_role
    install_conversion_host_module
    playbook = "/usr/share/ovirt-ansible-v2v-conversion-host/playbooks/conversion_host_disable.yml"
    extra_vars = {}
    ansible_playbook(playbook, extra_vars)
  ensure
    check_conversion_host_role
  end

  private

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

  def connect_ssh
    require 'MiqSshUtil'
    MiqSshUtil.shell_with_su(*miq_ssh_util_args) do |ssu, _shell|
      yield(ssu)
    end  
  rescue Exception => e
    _log.error("SSH connection failed for [#{ipaddress}] with [#{e.class}: #{e}]")
    raise e
  end

  def miq_ssh_util_args
    send("miq_ssh_util_args_#{resource.type.gsub('::', '_').downcase}")
  end

  def miq_ssh_util_args_manageiq_providers_redhat_inframanager_host
    [hostname || ipaddress, resource.authentication_userid, resource.authentication_password, nil, nil]
  end 

  def miq_ssh_util_args_manageiq_providers_openstack_cloudmanager_vm
    authentication = resource.ext_management_system.authentications
                             .where(:authtype => 'ssh_keypair')
                             .where.not(:userid => nil, :auth_key => nil)
                             .first
    [hostname || ipaddress, authentication.userid, nil, nil, nil, { :key_data => authentication.auth_key, :passwordless_sudo => true }]
  end

  def ansible_playbook(playbook, extra_vars, connection)
    command = "ansible-playbook #{playbook}"
    if connection == 'local'
      command += " -i localhost, -c #{connection}"
    else
      command += " -i #{ipaddress},"
    end
    extra_vars.each { |k, v| command += " -e '#{k}=#{v}'" }
    connect_ssh { |ssu| ssu.shell_exec(command) }
  rescue => e
    _log.error("Ansible playbook '#{playbook}' failed for '#{resource.name}' with [#{e.class}: #{e}]")
    raise e
  end

  def install_conversion_host_module
    connect_ssh { |ssu| ssu.shell_exec("yum install -y ovirt-ansible-v2v-conversion-host") }
  rescue => e
    _log.error("Ansible module installation failed for '#{resource.name}'}with [#{e.class}: #{e.message}]")
  end

  def tag_resource_as(status)
    send("tag_resource_as_#{status}")
  end

  def tag_resource_as_enabled
    resource.tag_add('v2v_transformation_host/true')
    resource.tag_add('v2v_transformation_method/vddk')
  end

  def tag_resource_as_disabled
    resource.tag_add('v2v_transformation_host/false')
    resource.tag_remove('v2v_transformation_method/vddk')
  end
end

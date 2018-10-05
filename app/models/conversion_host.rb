class ConversionHost < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :resource, :polymorphic => true
  has_many :service_template_transformation_plan_tasks, :dependent => :nullify
  has_many :active_tasks, -> { where(:state => 'active') }, :class_name => ServiceTemplateTransformationPlanTask, :inverse_of => :conversion_host

  # To be eligible, a conversion host must have the following properties
  #  - A transport mechanism is configured for source (set by 3rd party)
  #  - Credentials are set on the resource
  #  - The number of concurrent tasks has not reached the limit
  def eligible?
    source_transport_method.present? && check_resource_credentials && check_concurrent_tasks
  end

  def check_concurrent_tasks
    max_tasks = max_concurrent_tasks || Settings.transformation.limits.max_concurrent_tasks_per_host
    active_tasks.size < max_tasks
  end

  def check_resource_credentials
    send("check_resource_credentials_#{resource.ext_management_system.emstype}")
  end

  def source_transport_method
    return 'vddk' if vddk_transport_supported
    return 'ssh' if ssh_transport_supported
  end

  def ipaddresses
    resource.ipaddresses.unshift(address).unshift(resource.try(:ipaddress)).reject(&:blank?)
  end 

  def ipaddress(family = nil)
    ips = ipaddresses
    return ips.first unless %w(ipv4 ipv6).include?(family)
    ips.select { |ip| IPAddr.new(ip).send("#{family}?") }.first
  end 

  def ssh_credentials
    send("ssh_credentials_#{resource.type.gsub('::', '_').downcase}")
  end 

  def run_conversion(conversion_options)
    connect_ssh.su_exec('/usr/bin/virt-v2v-wrapper.py', nil, conversion_options.to_json)
  end

  def conversion_log(path)
    unless check_resource_credentials
      msg = "Credential was not found for host #{host.resource.name}. Download of transformation log aborted."
      _log.error(msg)
      raise MiqException::Error, msg 
    end 

    begin
      Net::SCP.download!(ipaddress, resourcece.authentication_userid, path, nil, :ssh => {:password => resource.authentication_password})
    rescue Net::SCP::Error => scp_err
      _log.error("Download of transformation log for #{description} with ID [#{id}] failed with error: #{scp_err.message}")
      raise scp_err
    end 
  end 

  private


  def check_resource_credentials_rhevm
    !(resource.authentication_userid.nil? || resource.authentication_password.nil?)
  end

  def check_resource_credentials_openstack
    ssh_authentications = resource.ext_management_system.authentications
                                  .where(:authtype => 'ssh_keypair')
                                  .where.not(:userid => nil, :auth_key => nil)
    !ssh_authentications.empty?
  end

  def ssh_credentials_options_manageiq_providers_redhat_inframanager_host
    raise "Userid for #{resource.name} is empty" if resource.authentication_userid.blank?
    raise "Password for #{resource.name} is empty" if resource.authentication_password.blank?
    return resource.authentication_userid, resource.authentication_password, nil, nil, {}
  end 

  def ssh_credentials_manageiq_providers_openstack_cloudmanager_vm
    ems = resource.ext_management_system
    authentication = ems.authentication.where(:authtype => 'ssh_keypair').first
    raise "SSH authentication for #{ems.name} does not exist" if authentication.nil?
    raise "Authentication user for #{ems.name} is empty" if authentication.userid.blank?
    raise "Authentication private key for #{ems.name} is empty" if authentication.auth_key.blank?
    return authentication.userid, nil, 'root', nil, { :key_data => authentication.auth_key, :keys_only => true, :passwordless_sudo => true }
  end

  def connect_ssh(options = {}) 
    require 'MiqSshUtil'

    rl_user, rl_password, su_user, su_password, additional_options = ssh_credentials
    options.merge!(ssh_session_options)

    prompt_delay = ::Settings.ssh.try(:authentication_prompt_delay)
    options[:authentication_prompt_delay] = prompt_delay unless prompt_delay.nil?

    users = su_user.nil? ? rl_user : "#{rl_user}/#{su_user}"
    _log.info("Initiating SSH connection to Host:[#{name}] using [#{hostname}] for user:[#{users}].  Options:[#{logged_options.inspect}]")
    begin
      MiqSshUtil.shell_with_su(ipaddress, rl_user, rl_password, su_user, su_password, options) do |ssu, _shell|
        yield(ssu)
      end  
    rescue Exception => err 
      raise err 
    end  
  end 
end

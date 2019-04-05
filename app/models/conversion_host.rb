require 'resolv'

class ConversionHost < ApplicationRecord
  include NewWithTypeStiMixin
  include AuthenticationMixin

  acts_as_miq_taggable

  belongs_to :resource, :polymorphic => true
  has_many :service_template_transformation_plan_tasks, :dependent => :nullify
  has_many :active_tasks, -> { where(:state => ['active', 'migrate']) },
    :class_name => "ServiceTemplateTransformationPlanTask",
    :inverse_of => :conversion_host

  delegate :ext_management_system, :hostname, :ems_ref, :to => :resource, :allow_nil => true

  validates :name, :presence => true
  validates :resource, :presence => true

  validates :address,
    :uniqueness => true,
    :format     => { :with => Resolv::AddressRegex },
    :inclusion  => { :in => ->(conversion_host) { conversion_host.resource.ipaddresses } },
    :unless     => ->(conversion_host) { conversion_host.resource.blank? || conversion_host.resource.ipaddresses.blank? },
    :presence   => false

  validate :resource_supports_conversion_host

  before_validation :name, :default_name, :on => :create

  include_concern 'Configurations'

  after_create :tag_resource_as_enabled
  after_destroy :tag_resource_as_disabled

  # Use the +auth_type+ if present, or check the first associated authentication
  # if any are directly associated with the conversion host. Otherwise, use the
  # default check which uses the associated resource's authentications.
  #
  # In practice there should only be one associated authentication.
  #
  # Subclasses should pass provider-specific +options+, such as proxy information.
  #
  # This method is necessary to comply with AuthenticationMixin interface.
  #--
  # TODO: Use the verify_credentials_ssh method in host.rb? Move that to the
  # AuthenticationMixin?
  #
  def verify_credentials(auth_type = nil, options = {})
    if authentications.empty?
      check_ssh_connection
    else
      require 'net/ssh'
      host = hostname || ipaddress

      auth = authentication_type(auth_type) || authentications.first

      ssh_options = { :timeout => 10, :logger => $log, :verbose => :error }

      case auth
      when AuthUseridPassword
        ssh_options[:auth_methods] = %w[password]
        ssh_options[:password] = auth.password
      when AuthPrivateKey
        ssh_options[:auth_methods] = %w[publickey hostbased]
        ssh_options[:key_data] = auth.auth_key
      else
        raise MiqException::MiqInvalidCredentialsError, _("Unknown auth type: #{auth.authtype}")
      end

      # Options from STI subclasses will override the defaults we've set above.
      ssh_options.merge!(options)

      Net::SSH.start(host, auth.userid, ssh_options) { |ssh| ssh.exec!('uname -a') }
    end
  rescue Net::SSH::AuthenticationFailed => err
    raise MiqException::MiqInvalidCredentialsError, _("Incorrect credentials - %{error_message}") % {:error_message => err.message}
  rescue Net::SSH::HostKeyMismatch => err
    raise MiqException::MiqSshUtilHostKeyMismatch, _("Host key mismatch - %{error_message}") % {:error_message => err.message}
  rescue Exception => err
    raise _("Unknown error - %{error_message}") % {:error_message => err.message}
  else
    true
  end

  # Returns a boolean indicating whether or not the conversion host is eligible
  # for use. To be eligible, a conversion host must have the following properties:
  #
  #  - A transport mechanism is configured for source (set by 3rd party).
  #  - Credentials are set on the conversion host and the SSH connection works.
  #  - The number of concurrent tasks has not reached the limit.
  #
  def eligible?
    source_transport_method.present? && verify_credentials && check_concurrent_tasks
  end

  # Returns a boolean indicating whether or not the current number of active tasks
  # exceeds the maximum number of allowable concurrent tasks specified in settings.
  #
  def check_concurrent_tasks
    max_tasks = max_concurrent_tasks || Settings.transformation.limits.max_concurrent_tasks_per_host
    active_tasks.size < max_tasks
  end

  # Check to see if we can connect to the conversion host using a simple 'uname -a'
  # command on the connection. The exact nature of the connection will depend on the
  # underlying provider.
  #
  def check_ssh_connection
    connect_ssh { |ssu| ssu.shell_exec('uname -a') }
    true
  rescue StandardError
    false
  end

  # If set, returns a string indicating the source transport method. This is
  # either 'vddk' or 'ssh'. If not set, returns nil.
  #
  def source_transport_method
    return 'vddk' if vddk_transport_supported?
    return 'ssh' if ssh_transport_supported?
  end

  # Returns the associated IP address for the conversion host in the given +family+.
  # If an address is set for the conversion host, then that address will be
  # returned. Otherwise, it will return the IP address of the associated resource.
  #
  def ipaddress(family = 'ipv4')
    return address if address.present? && IPAddr.new(address).send("#{family}?")
    resource.ipaddresses.detect { |ip| IPAddr.new(ip).send("#{family}?") }
  end

  def run_conversion(conversion_options)
    result = connect_ssh { |ssu| ssu.shell_exec('/usr/bin/virt-v2v-wrapper.py', nil, nil, conversion_options.to_json) }
    JSON.parse(result)
  rescue => e
    raise "Starting conversion failed on '#{resource.name}' with [#{e.class}: #{e}]"
  end

  # Kill a specific remote process over ssh, sending the specified +signal+, or 'TERM'
  # if no signal is specified.
  #
  def kill_process(pid, signal = 'TERM')
    connect_ssh { |ssu| ssu.shell_exec("/bin/kill -s #{signal} #{pid}") }
    true
  rescue
    false
  end

  # Retrieve the conversion state information from a remote file as a stream.
  # Then parse and return the stream data as a hash using JSON.parse.
  #
  def get_conversion_state(path)
    json_state = connect_ssh { |ssu| ssu.get_file(path, nil) }
    JSON.parse(json_state)
  rescue MiqException::MiqInvalidCredentialsError, MiqException::MiqSshUtilHostKeyMismatch => err
    raise "Failed to connect and retrieve conversion state data from file '#{path}' with [#{err.class}: #{err}"
  rescue JSON::ParserError
    raise "Could not parse conversion state data from file '#{path}': #{json_state}"
  rescue StandardError => err
    raise "Error retrieving and parsing conversion state file '#{path}' from '#{resource.name}' with [#{err.class}: #{err}"
  end

  # Get and return the contents of the remote conversion log at +path+.
  #
  def get_conversion_log(path)
    connect_ssh { |ssu| ssu.get_file(path, nil) }
  rescue => e
    raise "Could not get conversion log '#{path}' from '#{resource.name}' with [#{e.class}: #{e}"
  end

  def check_conversion_host_role
    playbook = "/usr/share/ovirt-ansible-v2v-conversion-host/playbooks/conversion_host_check.yml"
    ansible_playbook(playbook)
    tag_resource_as('enabled')
  rescue
    tag_resource_as('disabled')
  end

  def enable_conversion_host_role(vmware_vddk_package_url = nil, vmware_ssh_private_key = nil)
    raise "vddk_package_url is mandatory if transformation method is vddk" if vddk_transport_supported && vmware_vddk_package_url.nil?
    raise "ssh_private_key is mandatory if transformation_method is ssh" if ssh_transport_supported && vmware_ssh_private_key.nil?
    playbook = "/usr/share/ovirt-ansible-v2v-conversion-host/playbooks/conversion_host_enable.yml"
    extra_vars = {
      :v2v_transport_method => vddk_transport_supported ? 'vddk' : 'ssh',
      :v2v_vddk_package_url => vmware_vddk_package_url,
      :v2v_ssh_private_key  => vmware_ssh_private_key,
      :v2v_ca_bundle        => resource.ext_management_system.connection_configurations['default'].certificate_authority
    }.compact
    ansible_playbook(playbook, extra_vars)
  ensure
    check_conversion_host_role
  end

  def disable_conversion_host_role
    playbook = "/usr/share/ovirt-ansible-v2v-conversion-host/playbooks/conversion_host_disable.yml"
    ansible_playbook(playbook)
  ensure
    check_conversion_host_role
  end

  private

  # The Vm or Host provider subclass must support conversion hosts
  # using the SupportsFeature mixin.
  #
  def resource_supports_conversion_host
    if resource && !resource.supports_conversion_host?
      errors.add(:resource, resource.unsupported_reason(:conversion_host))
    end
  end

  # Find the credentials for the associated resource. By default it will
  # look for a v2v auth type. If that is not found, it will look for the
  # authentication associated with the resource using ssh_keypair or default,
  # in that order, as the authtype.
  #
  def find_credentials(msg = nil)
    authentication = authentication_type('v2v') ||
      resource.authentication_type('ssh_keypair') ||
      resource.authentication_type('default')

    unless authentication
      msg = "Credentials not found for conversion host #{name} or resource #{resource.name}"
      msg << " #{msg}" if msg
      _log.error(msg)
      raise MiqException::Error, msg
    end

    authentication
  end

  # Connect to the conversion host using the MiqSshUtil wrapper using the authentication
  # parameters appropriate for that type of resource.
  #
  def connect_ssh
    require 'MiqSshUtil'
    MiqSshUtil.shell_with_su(*miq_ssh_util_args) do |ssu, _shell|
      yield(ssu)
    end
  rescue Exception => e
    _log.error("SSH connection failed for [#{ipaddress}] with [#{e.class}: #{e}]")
    raise e
  end

  # Collect appropriate authentication information based on the resource type.
  #--
  # TODO: This should be handled by a ConversionHost subclass within each supported provider.
  #
  def miq_ssh_util_args
    send("miq_ssh_util_args_#{resource.type.gsub('::', '_').downcase}")
  end

  # For the Redhat provider, use the userid and password associated directly with the resource.
  #--
  # TODO: Move this to ManageIQ::Providers::Redhat::InfraManager::ConversionHost
  #
  def miq_ssh_util_args_manageiq_providers_redhat_inframanager_host
    authentication = find_credentials
    [hostname || ipaddress, authentication.userid, authentication.password, nil, nil]
  end

  # For the OpenStack provider, use the first authentication containing an ssh keypair that has
  # both a userid and auth key.
  #--
  # TODO: Move this to ManageIQ::Providers::OpenStack::CloudManager::ConversionHost
  #
  def miq_ssh_util_args_manageiq_providers_openstack_cloudmanager_vm
    authentication = find_credentials
    [hostname || ipaddress, authentication.userid, nil, nil, nil, { :key_data => authentication.auth_key, :passwordless_sudo => true }]
  end

  # Run the specified ansible playbook using the ansible-playbook command. The
  # +extra_vars+ option should be a hash of key/value pairs which, if present,
  # will be passed to the '-e' flag.
  #
  def ansible_playbook(playbook, extra_vars = {})
    command = "ansible-playbook #{playbook} -i #{ipaddress}"

    extra_vars[:v2v_host_type] = resource.ext_management_system.emstype
    extra_vars.each { |k, v| command += " -e '#{k}=#{v}'" }

    connect_ssh { |ssu| ssu.shell_exec(command) }
  rescue => e
    _log.error("Ansible playbook '#{playbook}' failed for '#{resource.name}' with [#{e.class}: #{e}]")
    raise e
  end

  # Wrapper method for the various tag_resource_as_xxx methods.
  #--
  # TODO: Do we need this?
  #
  def tag_resource_as(status)
    send("tag_resource_as_#{status}")
  end

  # Tag the associated resource as enabled. The following tags are set or removed:
  #
  # - 'v2v_transformation_host/true'  (added)
  # - 'v2v_transformation_host/vddk'  (added if vddk supported)
  # - 'v2v_transformation_host/ssh'   (added if ssh supported)
  # - 'v2v_transformation_host/false' (removed if present)
  #
  def tag_resource_as_enabled
    resource.tag_add('v2v_transformation_host/true')
    resource.tag_add('v2v_transformation_method/vddk') if vddk_transport_supported?
    resource.tag_add('v2v_transformation_method/ssh') if ssh_transport_supported?
    resource.tag_remove('v2v_transformation_host/false')
  end

  # Tag the associated resource as disabled. The following tags are set or removed:
  #
  # - 'v2v_transformation_host/false' (added)
  # - 'v2v_transformation_host/true'  (removed if present)
  # - 'v2v_transformation_host/vddk'  (removed if present)
  # - 'v2v_transformation_host/ssh'   (removed if present)
  #
  def tag_resource_as_disabled
    resource.tag_add('v2v_transformation_host/false')
    resource.tag_remove('v2v_transformation_host/true')
    resource.tag_remove('v2v_transformation_method/vddk')
    resource.tag_remove('v2v_transformation_method/ssh')
  end

  # Set the default name to the name of the associated resource.
  #
  def default_name
    self.name ||= resource&.name
  end
end

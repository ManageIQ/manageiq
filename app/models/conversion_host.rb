require 'resolv'

class ConversionHost < ApplicationRecord
  include NewWithTypeStiMixin
  include AuthenticationMixin

  acts_as_miq_taggable

  belongs_to :resource, :polymorphic => true
  has_many :service_template_transformation_plan_tasks, :dependent => :nullify
  has_many :active_tasks, -> { where(:state => ['active', 'migrate', 'pending']) },
    :class_name => "ServiceTemplateTransformationPlanTask",
    :inverse_of => :conversion_host

  delegate :ext_management_system, :hostname, :ems_ref, :to => :resource, :allow_nil => true

  validates :name, :presence => true
  validates :resource, :presence => true
  validates :resource_id, :uniqueness => { :scope => :resource_type }

  validates :address,
    :uniqueness => true,
    :format     => { :with => Resolv::AddressRegex },
    :inclusion  => { :in => ->(conversion_host) { conversion_host.resource.ipaddresses } },
    :unless     => ->(conversion_host) { conversion_host.address.blank? || conversion_host.resource.blank? || conversion_host.resource.ipaddresses.blank? },
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
  def verify_credentials(auth_type = 'v2v', options = {})
    if authentications.empty?
      check_ssh_connection
    else
      require 'net/ssh'
      host = hostname || ipaddress

      auth = authentication_type(auth_type) || authentications.first

      ssh_options = { :timeout => 10, :use_agent => false }

      case auth
      when AuthUseridPassword
        ssh_options[:auth_methods] = %w[password]
        ssh_options[:password] = auth.password
      when AuthPrivateKey
        ssh_options[:auth_methods] = %w[publickey hostbased]
        ssh_options[:key_data] = auth.auth_key
      else
        raise MiqException::MiqInvalidCredentialsError, _("Unknown auth type: %{auth_type}") % {:auth_type => auth.authtype}
      end

      # Don't connect again if the authentication is still valid
      return true if authentication_status_ok?(auth_type)

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
    source_transport_method.present? && authentication_check('v2v').first && check_concurrent_tasks
  end

  # Returns a boolean indication whether or not the conversion host is eligible
  # for warm migration. To be eligible, a conversion host must have the following
  # properties:
  #
  #  - The conversion is generally eligible, i.e. eligible? returns true
  #  - The VDDK transport method is supported
  def warm_migration_eligible?
    eligible? && source_transport_method == 'vddk'
  end

  # Returns a boolean indicating whether or not the current number of active tasks
  # exceeds the maximum number of allowable concurrent tasks specified in settings.
  #
  # Note that we force a reload of the active tasks via .count because we don't
  # want that value cached.
  #
  def check_concurrent_tasks
    max_tasks = max_concurrent_tasks || Settings.transformation.limits.max_concurrent_tasks_per_conversion_host
    active_tasks.count < max_tasks
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

  # Write the limits calculated by InfraConversionThrottler to a specific task.
  #
  # @param [String] path The path of the throttling file for the task
  # @param [Hash] limits The limits to apply, accordingly to virt-v2v-wrapper documentation
  #
  # @return [Integer] length of data written to file
  #
  # @raise [MiqException::MiqInvalidCredentialsError] if conversion host credentials are invalid
  # @raise [MiqException::MiqSshUtilHostKeyMismatch] if conversion host key has changed
  # @raise [JSON::GeneratorError] if limits hash can't be converted to JSON
  # @raise [StandardError] if any other problem happens
  def apply_task_limits(path, limits = {})
    connect_ssh { |ssu| ssu.put_file(path, limits.to_json) }
  rescue MiqException::MiqInvalidCredentialsError, MiqException::MiqSshUtilHostKeyMismatch => err
    raise "Failed to connect and apply limits in file '#{path}' with [#{err.class}: #{err}]"
  rescue JSON::GeneratorError => err
    raise "Could not generate JSON from limits '#{limits}' with [#{err.class}: #{err}]"
  rescue StandardError => err
    raise "Could not apply the limits in '#{path}' on '#{resource.name}' with [#{err.class}: #{err}]"
  end

  # Run the virt-v2v-wrapper script on the remote host and return a hash
  # result from the parsed JSON output.
  #
  # Certain sensitive fields are filtered in the error messages to prevent
  # that information from showing up in the UI or logs.
  #
  def run_conversion(conversion_options)
    ignore = %w[password fingerprint key]
    filtered_options = conversion_options.clone.tap { |h| h.each { |k, _v| h[k] = "__FILTERED__" if ignore.any? { |i| k.to_s.end_with?(i) } } }
    result = connect_ssh { |ssu| ssu.shell_exec('/usr/bin/virt-v2v-wrapper', nil, nil, conversion_options.to_json) }
    JSON.parse(result)
  rescue MiqException::MiqInvalidCredentialsError, MiqException::MiqSshUtilHostKeyMismatch => err
    raise "Failed to connect and run conversion using options #{filtered_options} with [#{err.class}: #{err}]"
  rescue JSON::ParserError
    raise "Could not parse result data after running virt-v2v-wrapper using options: #{filtered_options}. Result was: #{result}."
  rescue StandardError => err
    raise "Starting conversion failed on '#{resource.name}' with [#{err.class}: #{err}]"
  end

  def create_cutover_file(path)
    connect_ssh { |ssu| ssu.shell_exec("touch #{path}") }
    true
  rescue StandardError
    false
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

  def check_conversion_host_role(miq_task_id = nil)
    playbook = "/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_check.yml"
    extra_vars = {
      :v2v_host_type        => resource.ext_management_system.emstype,
      :v2v_transport_method => source_transport_method
    }
    ansible_playbook(playbook, extra_vars, miq_task_id)
    tag_resource_as('enabled')
  rescue
    tag_resource_as('disabled')
  end

  def enable_conversion_host_role(vmware_vddk_package_url = nil, vmware_ssh_private_key = nil, openstack_tls_ca_certs = nil, miq_task_id = nil)
    raise "vmware_vddk_package_url is mandatory if transformation method is vddk" if vddk_transport_supported && vmware_vddk_package_url.nil?
    raise "vmware_ssh_private_key is mandatory if transformation_method is ssh" if ssh_transport_supported && vmware_ssh_private_key.nil?
    playbook = "/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_enable.yml"
    extra_vars = {
      :v2v_host_type        => resource.ext_management_system.emstype,
      :v2v_transport_method => source_transport_method,
      :v2v_vddk_package_url => vmware_vddk_package_url,
      :v2v_ssh_private_key  => vmware_ssh_private_key,
      :v2v_ca_bundle        => openstack_tls_ca_certs || resource.ext_management_system.connection_configurations['default'].certificate_authority
    }.compact
    ansible_playbook(playbook, extra_vars, miq_task_id)
  ensure
    check_conversion_host_role(miq_task_id)
  end

  def disable_conversion_host_role(miq_task_id = nil)
    playbook = "/usr/share/v2v-conversion-host-ansible/playbooks/conversion_host_disable.yml"
    extra_vars = {
      :v2v_host_type        => resource.ext_management_system.emstype,
      :v2v_transport_method => source_transport_method
    }
    ansible_playbook(playbook, extra_vars, miq_task_id)
  ensure
    check_conversion_host_role(miq_task_id)
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
  # look for a v2v auth type if no argument is passed in.
  #
  # If one isn't found, then it will look for the authentication associated
  # with the resource using the 'ssh_keypair' auth type, and finally 'default'.
  #
  def find_credentials(auth_type = 'v2v')
    authentication = authentications.detect { |a| a.authtype == auth_type }

    if authentication.blank?
      res = resource.respond_to?(:authentication_type) ? resource : resource.ext_management_system
      authentication = res.authentication_type('ssh_keypair') || res.authentication_type('default')
    end

    unless authentication
      error_msg = "Credentials not found for conversion host #{name} or resource #{resource.name}"
      _log.error(error_msg)
      raise MiqException::Error, error_msg
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

  # Collect appropriate authentication information based on the authentication type.
  #
  def miq_ssh_util_args
    host = hostname || ipaddress
    authentication = find_credentials
    case authentication.type
    when 'AuthPrivateKey', 'AuthToken'
      [host, authentication.userid, nil, nil, nil, { :key_data => authentication.auth_key, :passwordless_sudo => true }]
    when 'AuthUseridPassword'
      [host, authentication.userid, authentication.password, nil, nil]
    else
      raise "Unsupported authentication type: #{authentication.type}"
    end
  end

  # Run the specified ansible playbook using the ansible-playbook command. The
  # +extra_vars+ option should be a hash of key/value pairs which, if present,
  # will be passed to the '-e' flag.
  #
  def ansible_playbook(playbook, extra_vars = {}, miq_task_id = nil, auth_type = 'v2v')
    task = MiqTask.find(miq_task_id) if miq_task_id.present?

    host = hostname || ipaddress

    command = "ansible-playbook #{playbook} --inventory #{host}, --become --extra-vars=\"ansible_ssh_common_args='-o StrictHostKeyChecking=no'\""

    auth = find_credentials(auth_type)
    command << " --user #{auth.userid}"

    case auth
    when AuthUseridPassword
      extra_vars[:ansible_ssh_pass] = auth.password
    when AuthPrivateKey
      ssh_private_key_file = Tempfile.new('ansible_key')
      begin
        ssh_private_key_file.write(auth.auth_key)
      ensure
        ssh_private_key_file.close
      end
      command << " --private-key #{ssh_private_key_file.path}"
    else
      raise MiqException::MiqInvalidCredentialsError, _("Unknown auth type: %{auth_type}") % {:auth_type => auth.authtype}
    end

    command << " --extra-vars '#{extra_vars.to_json}'"

    result = AwesomeSpawn.run(command)

    if result.failure?
      error_message = result.error.presence || result.output
      _log.error("#{result.command_line} ==> #{error_message}")
      raise
    end
  ensure
    task&.update_context(task.context_data.merge!(File.basename(playbook, '.yml') => result.output)) unless result.nil?
    ssh_private_key_file&.unlink
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

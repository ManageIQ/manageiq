class ManageIQ::Providers::Vmware::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :OrchestrationStack
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :Template
  require_nested :Vm

  include ManageIQ::Providers::Vmware::CloudManagerMixinEvents

  def self.ems_type
    @ems_type ||= "vmware_cloud".freeze
  end

  def self.description
    @description ||= "VMware vCloud".freeze
  end

  def self.default_blacklisted_event_names
    []
  end

  def self.hostname_required?
    true
  end

  def supports_port?
    true
  end

  def supported_auth_types
    %w(default amqp)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  #
  # Connections
  #

  def self.raw_connect(server, port, api_version, username, password)
    require 'fog/vcloud_director'

    params = {
      :vcloud_director_username      => username,
      :vcloud_director_password      => password,
      :vcloud_director_host          => server,
      :port                          => port,
      :vcloud_director_api_version   => api_version,
      :vcloud_director_show_progress => false,
      :connection_options            => {
        :ssl_verify_peer => false # for development
      }
    }

    Fog::Compute::VcloudDirector.new(params)
  end

  def connect(options = {})
    raise "no credentials defined" if missing_credentials?(options[:auth_type])

    server      = options[:ip] || address
    port        = options[:port] || self.port
    api_version = options[:api_version] || self.api_version
    username    = options[:user] || authentication_userid(options[:auth_type])
    password    = options[:pass] || authentication_password(options[:auth_type])

    self.class.raw_connect(server, port, api_version, username, password)
  end

  #
  # Operations
  #

  def vm_start(vm, _options = {})
    vm.start
  rescue => err
    _log.error "vm=[#{vm.name}, error: #{err}"
  end

  def vm_stop(vm, _options = {})
    vm.stop
  rescue => err
    _log.error "vm=[#{vm.name}, error: #{err}"
  end

  def vm_suspend(vm, _options = {})
    vm.suspend
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_restart(vm, _options = {})
    vm.restart
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def translate_exception(err)
    case err
    when Fog::Compute::VcloudDirector::Unauthorized
      MiqException::MiqInvalidCredentialsError.new "Login failed due to a bad username or password."
    when Excon::Errors::Timeout
      MiqException::MiqUnreachableError.new "Login attempt timed out"
    when Excon::Errors::SocketError
      MiqException::MiqHostError.new "Socket error: #{err.message}"
    when MiqException::MiqInvalidCredentialsError, MiqException::MiqHostError
      err
    else
      MiqException::MiqHostError.new "Unexpected response returned from system: #{err.message}"
    end
  end

  def verify_credentials(auth_type = nil, options = {})
    auth_type ||= 'default'
    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(auth_type)

    options[:auth_type] = auth_type

    case auth_type.to_s
    when 'default' then
      begin
        with_provider_connection(options) do |vcd|
          vcd.organizations.all
        end
      rescue => err
        miq_exception = translate_exception(err)
        _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
        raise miq_exception
      end
    when 'amqp' then verify_amqp_credentials(options)
    else
      raise "Invalid Vmware vCloud Authentication Type: #{auth_type.inspect}"
    end

    true
  end
end

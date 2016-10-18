module ManageIQ::Providers::Openstack::ManagerMixin
  extend ActiveSupport::Concern

  included do
    after_save :stop_event_monitor_queue_on_change
    before_destroy :stop_event_monitor
  end

  alias_attribute :keystone_v3_domain_id, :uid_ems
  #
  # OpenStack interactions
  #
  module ClassMethods
    def raw_connect(username, password, auth_url, service = "Compute")
      require 'openstack/openstack_handle'
      OpenstackHandle::Handle.raw_connect(username, password, auth_url, service)
    end

    def auth_url(address, port = nil)
      require 'openstack/openstack_handle'
      OpenstackHandle::Handle.auth_url(address, port)
    end
  end

  def auth_url
    self.class.auth_url(address, port)
  end

  def browser_url
    "http://#{address}/dashboard"
  end

  def openstack_handle(options = {})
    require 'openstack/openstack_handle'
    @openstack_handle ||= begin
      raise MiqException::MiqInvalidCredentialsError, "No credentials defined" if self.missing_credentials?(options[:auth_type])

      username = options[:user] || authentication_userid(options[:auth_type])
      password = options[:pass] || authentication_password(options[:auth_type])

      vmdb_config = VMDB::Config.new("vmdb").config
      extra_options = {
        :ssl_ca_file    => vmdb_config.fetch_path(:ssl, :ssl_ca_file),
        :ssl_ca_path    => vmdb_config.fetch_path(:ssl, :ssl_ca_path),
        :ssl_cert_store => OpenSSL::X509::Store.new
      }
      extra_options[:domain_id] = keystone_v3_domain_id
      extra_options[:region]    = provider_region if provider_region.present?

      osh = OpenstackHandle::Handle.new(username, password, address, port, api_version, security_protocol, extra_options)
      osh.connection_options = {:instrumentor => $fog_log}
      osh
    end
  end

  def reset_openstack_handle
    @openstack_handle = nil
  end

  def connect(options = {})
    openstack_handle(options).connect(options)
  end

  def connect_volume
    connect(:service => "Volume")
  end

  def connect_identity
    connect(:service => "Identity")
  end

  def event_monitor_options
    @event_monitor_options ||= begin
      opts = {:ems => self, :automatic_recovery => false, :recover_from_connection_close => false}

      ceilometer = connection_configuration_by_role("ceilometer")

      if ceilometer.try(:endpoint) && !ceilometer.try(:endpoint).try(:marked_for_destruction?)
        opts[:events_monitor] = :ceilometer
      elsif (amqp = connection_configuration_by_role("amqp"))
        opts[:events_monitor] = :amqp
        if (endpoint = amqp.try(:endpoint))
          opts[:hostname]          = endpoint.hostname
          opts[:port]              = endpoint.port
          opts[:security_protocol] = endpoint.security_protocol
        end

        if (authentication = amqp.try(:authentication))
          opts[:username] = authentication.userid
          opts[:password] = authentication.password
        end
      end
      opts
    end
  end

  def event_monitor_available?
    require 'openstack/openstack_event_monitor'
    OpenstackEventMonitor.available?(event_monitor_options)
  rescue => e
    _log.error("Exception trying to find openstack event monitor for #{name}(#{hostname}). #{e.message}")
    _log.error(e.backtrace.join("\n"))
    false
  end

  def stop_event_monitor_queue_on_change
    if event_monitor_class && !self.new_record? && (authentications.detect{ |x| x.previous_changes.present? } ||
                                                    endpoints.detect{ |x| x.previous_changes.present? })
      _log.info("EMS: [#{name}], Credentials or endpoints have changed, stopping Event Monitor. It will be restarted by the WorkerMonitor.")
      stop_event_monitor_queue
      network_manager.stop_event_monitor_queue if try(:network_manager) && !network_manager.new_record?
    end
  end

  def stop_event_monitor_queue_on_credential_change
    # TODO(lsmola) this check should not be needed. Right now we are saving each individual authentication and
    # it is breaking the check for changes. We should have it all saved by autosave when saving EMS, so the code
    # for authentications needs to be rewritten.
    stop_event_monitor_queue_on_change
  end

  def translate_exception(err)
    require 'excon'
    case err
    when Excon::Errors::Unauthorized
      MiqException::MiqInvalidCredentialsError.new "Login failed due to a bad username or password."
    when Excon::Errors::Timeout
      MiqException::MiqUnreachableError.new "Login attempt timed out"
    when Excon::Errors::SocketError
      MiqException::MiqHostError.new "Socket error: #{err.message}"
    when MiqException::MiqInvalidCredentialsError, MiqException::MiqHostError
      err
    else
      MiqException::MiqEVMLoginError.new "Unexpected response returned from system: #{err.message}"
    end
  end

  def verify_api_credentials(options = {})
    options[:service] = "Compute"
    with_provider_connection(options) {}
    true
  rescue => err
    miq_exception = translate_exception(err)
    raise unless miq_exception

    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise miq_exception
  end
  private :verify_api_credentials

  def verify_amqp_credentials(_options = {})
    require 'openstack/openstack_event_monitor'
    OpenstackEventMonitor.test_amqp_connection(event_monitor_options)
  rescue => err
    miq_exception = translate_exception(err)
    raise unless miq_exception

    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise miq_exception
  end
  private :verify_amqp_credentials

  def verify_credentials(auth_type = nil, options = {})
    auth_type ||= 'default'

    raise MiqException::MiqHostError, "No credentials defined" if self.missing_credentials?(auth_type)

    options.merge!(:auth_type => auth_type)
    case auth_type.to_s
    when 'default' then verify_api_credentials(options)
    when 'amqp' then    verify_amqp_credentials(options)
    else;           raise "Invalid OpenStack Authentication Type: #{auth_type.inspect}"
    end
  end

  def required_credential_fields(_type)
    [:userid, :password]
  end

  def orchestration_template_validate(template)
    openstack_handle.orchestration_service.templates.validate(:template => template.content)
    nil
  rescue Excon::Errors::BadRequest => bad
    JSON.parse(bad.response.body)['error']['message']
  rescue => err
    _log.error "template=[#{template.name}], error: #{err}"
    raise MiqException::MiqOrchestrationValidationError, err.to_s, err.backtrace
  end

  delegate :description, :to => :class
end

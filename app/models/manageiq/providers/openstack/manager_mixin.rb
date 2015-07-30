module ManageIQ::Providers::Openstack::ManagerMixin
  extend ActiveSupport::Concern

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

      username = options[:user] || self.authentication_userid(options[:auth_type])
      password = options[:pass] || self.authentication_password(options[:auth_type])

      osh = OpenstackHandle::Handle.new(username, password, address, port)
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
      opts = {:hostname => self.hostname}
      opts[:port] = event_monitor_class.worker_settings[:amqp_port]
      if self.has_authentication_type? :amqp
        # authentication_userid/password will happily return the "default"
        # userid/password if this ems has no amqp auth configured
        opts[:username] = self.authentication_userid(:amqp)
        opts[:password] = self.authentication_password(:amqp)
      end
      opts
    end
  end

  def event_monitor_available?
    require 'openstack/openstack_event_monitor'
    OpenstackEventMonitor.available?(event_monitor_options)
  rescue => e
    _log.error("Exeption trying to find openstack event monitor for #{self.name}(#{self.hostname}). #{e.message}")
    false
  end

  def translate_exception(err)
    case err
    when Excon::Errors::Unauthorized
      MiqException::MiqInvalidCredentialsError.new "Login failed due to a bad username or password."
    when Excon::Errors::Timeout
      MiqException::MiqUnreachableError.new "Login attempt timed out"
    when Excon::Errors::SocketError
      MiqException::MiqHostError.new "Socket error: #{err.message}"
    when MiqException::MiqInvalidCredentialsError
      err
    else
      MiqException::MiqEVMLoginError.new "Unexpected response returned from system: #{err.message}"
    end
  end

  def verify_api_credentials(options={})
    options[:service] = "Identity"
    with_provider_connection(options) {}
    true
  rescue => err
    miq_exception = translate_exception(err)
    raise unless miq_exception

    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise miq_exception
  end
  private :verify_api_credentials

  def verify_amqp_credentials(options={})
    require 'openstack/openstack_event_monitor'
    OpenstackEventMonitor.test_amqp_connection(event_monitor_options)
    true
  rescue => err
    miq_exception = translate_exception(err)
    raise unless miq_exception

    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise miq_exception
  end
  private :verify_amqp_credentials

  def verify_credentials(auth_type=nil, options={})
    auth_type ||= 'default'

    raise MiqException::MiqHostError, "No credentials defined" if self.missing_credentials?(auth_type)

    options.merge!(:auth_type => auth_type)
    case auth_type.to_s
    when 'default'; verify_api_credentials(options)
    when 'amqp';    verify_amqp_credentials(options)
    else;           raise "Invalid OpenStack Authentication Type: #{auth_type.inspect}"
    end
  end

  def required_credential_fields(_type)
    [:userid, :password]
  end

  def stack_create(stack_name, template, options = {})
    create_options = {:stack_name => stack_name, :template => template.content}.merge(options.except(:tenant_name))
    openstack_handle.orchestration_service(options[:tenant_name]).stacks.new.save(create_options)["id"]
  rescue => err
    _log.error "stack=[#{stack_name}], error: #{err}"
    raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
  end

  def stack_status(stack_name, stack_id, options = {})
    stack = openstack_handle.orchestration_service(options[:tenant_name]).stacks.get(stack_name, stack_id)
    return stack.stack_status, stack.stack_status_reason if stack
  rescue => err
    _log.error "stack=[#{stack_name}], error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
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

  def description
    self.class.description
  end
end

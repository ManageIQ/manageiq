class EmsOpenstack < EmsCloud
  def self.default_vm_type
    @default_vm_type ||= "VmOpenstack".freeze
  end

  def self.default_template_type
    @default_template_type ||= "TemplateOpenstack".freeze
  end

  def self.ems_type
    @ems_type ||= "openstack".freeze
  end

  def self.description
    @description ||= "OpenStack".freeze
  end

  #
  # OpenStack interactions
  #

  def self.raw_connect(username, password, auth_url, service = "Compute")
    require 'openstack/openstack_handle'
    OpenstackHandle::Handle.raw_connect(username, password, auth_url, service)
  end

  def self.auth_url(address, port = nil)
    require 'openstack/openstack_handle'
    OpenstackHandle::Handle.auth_url(address, port)
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
      raise "no credentials defined" if self.authentication_invalid?(options[:auth_type])

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
      opts = {:hostname => self.ipaddress}
      opts[:port] = MiqEventCatcherOpenstack.worker_settings[:amqp_port]
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
    $log.error("MIQ(#{self.class.name}.#{__method__}) Exeption trying to find openstack event monitor for #{self.name}(#{self.hostname}). #{e.message}")
    false
  end

  def verify_api_credentials(options={})
    begin
      with_provider_connection(options) {}
    rescue Excon::Errors::Unauthorized => err
      $log.error("MIQ(#{self.class.name}.verify_api_credentials) Error Class=#{err.class.name}, Message=#{err.message}")
      raise MiqException::MiqEVMLoginError, "Login failed due to a bad username or password."
    rescue Exception => err
      $log.error("MIQ(#{self.class.name}.verify_api_credentials) Error Class=#{err.class.name}, Message=#{err.message}")
      raise MiqException::MiqEVMLoginError, "Unexpected response returned from system, see log for details"
    end
    true
  end
  private :verify_api_credentials

  def verify_amqp_credentials(options={})
    require 'openstack/openstack_event_monitor'
    OpenstackEventMonitor.test_amqp_connection(event_monitor_options)
  rescue Exception => e
    $log.error("MIQ(#{self.class.name}.verify_amqp_credentials) Error Class=#{e.class.name}, Message=#{e.message}")
    raise MiqException::MiqEVMLoginError, e.to_s
  end
  private :verify_amqp_credentials

  def verify_credentials(auth_type=nil, options={})
    auth_type ||= 'default'

    raise MiqException::MiqHostError, "No credentials defined" if self.authentication_invalid?(auth_type)

    options.merge!(:auth_type => auth_type)
    case auth_type.to_s
    when 'default'; verify_api_credentials(options)
    when 'amqp';    verify_amqp_credentials(options)
    else;           raise "Invalid OpenStack Authentication Type: #{auth_type.inspect}"
    end
  end

  #
  # Operations
  #

  def vm_start(vm, options = {})
    vm.start
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_pause(vm, options = {})
    vm.pause
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_suspend(vm, options = {})
    vm.suspend
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_destroy(vm, options = {})
    vm.vm_destroy
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_reboot_guest(vm, options = {})
    vm.reboot_guest
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_reset(vm, options = {})
    vm.reset
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end
end

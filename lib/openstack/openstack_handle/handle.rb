require 'active_support/inflector'
require 'util/miq-exception'

class OpenstackHandle
  attr_accessor :username, :password, :address, :port, :connection_options
  attr_writer   :default_tenant_name

  def self.raw_connect(username, password, auth_url, service = "Compute", extra_opts = nil)
    require 'fog'

    opts = {
      :provider           => 'OpenStack',
      :openstack_auth_url => auth_url,
      :openstack_username => username,
      :openstack_api_key  => password,
    }
    opts.merge!(extra_opts) if extra_opts

    Fog.const_get(service).new(opts)
  rescue Fog::Errors::NotFound => err
    raise MiqException::ServiceNotAvailable if err.message.include?("Could not find service")
    raise
  end

  def self.auth_url(address, port = 5000)
    "http://#{address}:#{port}/v2.0/tokens"
  end

  def self.connection_options=(hash)
    @connection_options = hash
  end

  def self.connection_options
    @connection_options
  end

  def initialize(username, password, address, port = nil)
    @username = username
    @password = password
    @address  = address
    @port     = port || 5000

    @connection_cache   = {}
    @connection_options = self.class.connection_options
  end

  def auth_url
    self.class.auth_url(address, port)
  end

  def browser_url
    "http://#{address}/dashboard"
  end

  def connect(options = {})
    opts = options.dup
    service  = (opts.delete(:service) || "Compute").to_s.camelize
    if (tenant = opts.delete(:tenant_name))
      opts[:openstack_tenant] = tenant
    end
    auth_url = self.class.auth_url(address, port)
    opts[:connection_options] = connection_options if connection_options

    self.class.raw_connect(username, password, auth_url, service, opts)
  end

  def compute_service(tenant_name = nil)
    connect_cache("Compute", tenant_name)
  end
  alias_method :connect_compute, :compute_service

  def identity_service
    @identity_service ||= connect(:service => "Identity")
  end
  alias_method :connect_identity, :identity_service

  def network_service(tenant_name = nil)
    connect_cache("Network", tenant_name)
  end
  alias_method :connect_network, :network_service

  def detect_network_service(tenant_name = nil)
    ns = network_service(tenant_name)
    @network_service_name = :neutron
    ns
  rescue MiqException::ServiceNotAvailable
    ns = compute_service(tenant_name)
    @network_service_name = :nova
    ns
  end

  def network_service_name
    return @network_service_name if @network_service_name
    detect_network_service
    @network_service_name
  end

  def image_service(tenant_name = nil)
    connect_cache("Image", tenant_name)
  end
  alias_method :connect_image, :image_service

  def detect_image_service(tenant_name = nil)
    is = image_service(tenant_name)
    @image_service_name = :glance
    is
  rescue MiqException::ServiceNotAvailable
    is = compute_service(tenant_name)
    @image_service_name = :nova
    is
  end

  def image_service_name
    return @image_service_name if @image_service_name
    detect_image_service
    @image_service_name
  end

  def volume_service(tenant_name = nil)
    connect_cache("Volume", tenant_name)
  end
  alias_method :connect_volume, :volume_service

  def detect_volume_service(tenant_name = nil)
    vs = volume_service(tenant_name)
    @volume_service_name = :cinder
    vs
  rescue MiqException::ServiceNotAvailable
    vs = compute_service(tenant_name)
    @volume_service_name = :nova
    vs
  end

  def volume_service_name
    return @volume_service_name if @volume_service_name
    detect_volume_service
    @volume_service_name
  end

  def storage_service(tenant_name = nil)
    connect_cache("Storage", tenant_name)
  end
  alias_method :connect_storage, :storage_service

  def detect_storage_service(tenant_name = nil)
    vs = storage_service(tenant_name)
    @storage_service_name = :swift
    vs
  rescue MiqException::ServiceNotAvailable
    @storage_service_name = :none
    nil
  end

  def storage_service_name
    return @storage_service_name if @storage_service_name
    detect_storage_service
    @storage_service_name
  end

  def tenants
    @tenants ||= identity_service.tenants
  end

  def tenant_names
    @tenant_names ||= tenants.collect { |t| t.name }
  end

  def default_tenant_name
    @default_tenant_name ||= tenant_names.detect { |tn| tn != "services" }
  end

  private

  def connect_cache(service, tenant_name)
    tenant_name ||= default_tenant_name
    svc_cache = (@connection_cache[service] ||= {})
    svc_cache[tenant_name] ||= connect(:service => service, :tenant_name => tenant_name)
  end
end

require 'active_support/inflector'
require 'util/miq-exception'

module OpenstackHandle
  class Handle
    attr_accessor :username, :password, :address, :port, :connection_options
    attr_writer   :default_tenant_name

    SERVICE_FALL_BACK = {
      "Network"  => "Compute",
      "Image"    => "Compute",
      "Volume"   => "Compute",
      "Storage"  => nil,
      "Metering" => nil
    }

    SERVICE_NAME_MAP = {
      "Compute"       => :nova,
      "Network"       => :neutron,
      "Image"         => :glance,
      "Volume"        => :cinder,
      "Storage"       => :swift,
      "Metering"      => :ceilometer,
      "Baremetal"     => :baremetal,
      "Orchestration" => :orchestration
    }

    def self.raw_connect_try_ssl(username, password, address, port, service = "Compute", opts = nil)
      auth_url = auth_url(address, port)
      begin
        # attempt to connect without SSL
        raw_connect(username, password, auth_url, service, opts)
      rescue Excon::Errors::SocketError => err
        raise unless err.message.include?("end of file reached (EOFError)")
        # if the error looks like an SSL-related failure, try again with SSL
        auth_url = auth_url(address, port, true)
        opts[:connection_options] = (opts[:connection_options] || {}).merge(:ssl_verify_peer => false)
        raw_connect(username, password, auth_url, service, opts)
      end
    end

    def self.raw_connect(username, password, auth_url, service = "Compute", extra_opts = nil)
      opts = {
        :provider           => 'OpenStack',
        :openstack_auth_url => auth_url,
        :openstack_username => username,
        :openstack_api_key  => password,
      }
      opts.merge!(extra_opts) if extra_opts

      # Workaround for a bug in Fog
      # https://github.com/fog/fog/issues/3112
      # Ensure the that if the Storage service is not available, it will not
      # throw an error trying to build an connection error message.
      opts[:openstack_service_type] = ["object-store"] if service == "Storage"

      Fog.const_get(service).new(opts)
    rescue Fog::Errors::NotFound => err
      raise MiqException::ServiceNotAvailable if err.message.include?("Could not find service")
      raise
    end

    def self.auth_url(address, port = 5000, ssl = false)
      scheme = ssl ? "https" : "http"
      "#{scheme}://#{address}:#{port}/v2.0/tokens"
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

      @service_names      = {}
      @connection_cache   = {}
      @connection_options = self.class.connection_options
    end

    def browser_url
      "http://#{address}/dashboard"
    end

    def connect(options = {})
      opts = options.dup
      service  = (opts.delete(:service) || "Compute").to_s.camelize
      tenant = opts.delete(:tenant_name)
      unless tenant
        tenant = "any_tenant" if service == "Identity"
        tenant ||= default_tenant_name
      end
      opts[:openstack_tenant] = tenant unless service == "Identity"

      svc_cache = (@connection_cache[service] ||= {})
      svc_cache[tenant] ||= begin
        opts[:connection_options] = connection_options if connection_options

        raw_service = self.class.raw_connect_try_ssl(username, password, address, port, service, opts)
        service_wrapper_name = "#{service}Delegate"
        # Allow openstack to define new services without explicitly requiring a
        # service wrapper.
        if OpenstackHandle.const_defined?(service_wrapper_name)
          OpenstackHandle.const_get(service_wrapper_name).new(raw_service, self)
        else
          raw_service
        end
      end
    end

    def baremetal_service(tenant_name = nil)
      connect(:service => "Baremetal", :tenant_name => tenant_name)
    end

    def detect_baremetal_service(tenant_name = nil)
      detect_service("Baremetal", tenant_name)
    end

    def baremetal_service_name
      service_name("Baremetal")
    end

    def orchestration_service(tenant_name = nil)
      connect(:service => "Orchestration", :tenant_name => tenant_name)
    end

    def detect_orchestration_service(tenant_name = nil)
      detect_service("Orchestration", tenant_name)
    end

    def orchestration_service_name
      service_name("Orchestration")
    end

    def compute_service(tenant_name = nil)
      connect(:service => "Compute", :tenant_name => tenant_name)
    end
    alias_method :connect_compute, :compute_service

    def identity_service
      connect(:service => "Identity")
    end
    alias_method :connect_identity, :identity_service

    def network_service(tenant_name = nil)
      connect(:service => "Network", :tenant_name => tenant_name)
    end
    alias_method :connect_network, :network_service

    def detect_network_service(tenant_name = nil)
      detect_service("Network", tenant_name)
    end

    def network_service_name
      service_name("Network")
    end

    def image_service(tenant_name = nil)
      connect(:service => "Image", :tenant_name => tenant_name)
    end
    alias_method :connect_image, :image_service

    def detect_image_service(tenant_name = nil)
      detect_service("Image", tenant_name)
    end

    def image_service_name
      service_name("Image")
    end

    def volume_service(tenant_name = nil)
      connect(:service => "Volume", :tenant_name => tenant_name)
    end
    alias_method :connect_volume, :volume_service

    def detect_volume_service(tenant_name = nil)
      detect_service("Volume", tenant_name)
    end

    def volume_service_name
      service_name("Volume")
    end

    def storage_service(tenant_name = nil)
      connect(:service => "Storage", :tenant_name => tenant_name)
    end
    alias_method :connect_storage, :storage_service

    def detect_storage_service(tenant_name = nil)
      detect_service("Storage", tenant_name)
    end

    def storage_service_name
      service_name("Storage")
    end

    def detect_service(service, tenant_name = nil)
      svc = connect(:service => service, :tenant_name => tenant_name)
      @service_names[service] = SERVICE_NAME_MAP[service]

      #
      # For non-admin users, if the Swift ACLs aren't set to permit
      # read access for the user, we'll be able to connect to the
      # service but it will fail on first access.
      #
      # We check for that situation here, and treat it as though the
      # service isn't available when encountered.
      #
      if service == "Storage"
        begin
          svc.directories.length
        rescue Excon::Errors::Forbidden
          @service_names[service] = :none
          return nil
        end
      end
      svc
    rescue MiqException::ServiceNotAvailable
      unless (fbs = SERVICE_FALL_BACK[service])
        @service_names[service] = :none
        return nil
      end
      svc = connect(:service => fbs, :tenant_name => tenant_name)
      @service_names[service] = SERVICE_NAME_MAP[fbs]
      svc
    end

    def service_name(service)
      return @service_names[service] if @service_names[service]
      detect_service(service)
      @service_names[service]
    end

    def tenants
      @tenants ||= identity_service.visible_tenants
    end

    def tenant_names
      @tenant_names ||= tenants.collect(&:name)
    end

    def accessible_tenants
      @accessible_tenants ||= tenants.select do |t|
        # avoid 401 Unauth errors when checking for accessible tenants
        # the "services" tenant is a special tenant in openstack reserved
        # specifically for the various services
        next if t.name == "services"
        begin
          compute_service(t.name)
          true
        rescue Excon::Errors::Unauthorized
          false
        end
      end
    end

    def accessible_tenant_names
      @accessible_tenant_names ||= accessible_tenants.collect(&:name)
    end

    def default_tenant_name
      return @default_tenant_name ||= "admin" if accessible_tenant_names.include?("admin")
      @default_tenant_name ||= accessible_tenant_names.detect { |tn| tn != "services" }
    end

    def service_for_each_accessible_tenant(service, &block)
      if block.arity == 1
        accessible_tenant_names.each { |t| block.call(detect_service(service, t)) }
      elsif block.arity == 2
        accessible_tenants.each { |t| block.call(detect_service(service, t.name), t) }
      else
        raise "OpenstackHandle#service_for_each_accessible_tenant: unexpected number of block args: #{block.arity}"
      end
    end

    def accessor_for_accessible_tenants(service, accessor, uniq_id, array_accessor = true)
      ra = []
      service_for_each_accessible_tenant(service) do |svc|
        not_found_error = Fog.const_get(service)::OpenStack::NotFound

        rv = begin
          svc.send(accessor)
        rescue not_found_error => e
          $fog_log.warn("MIQ(#{self.class.name}.#{__method__}) HTTP 404 Error during OpenStack request. " \
                        "Skipping inventory item #{service} #{accessor}\n#{e}")
          nil
        end

        if rv
          if array_accessor
            ra.concat(rv.to_a)
          else
            ra << rv
          end
        end
      end
      return ra unless uniq_id
      ra.uniq { |i| i.kind_of?(Hash) ? i[uniq_id] : i.send(uniq_id) }
    end
  end
end

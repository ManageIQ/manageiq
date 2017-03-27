require 'openssl'
require 'resolv'

module ManageIQ::Providers::Redhat::InfraManager::ApiIntegration
  extend ActiveSupport::Concern

  require 'ovirtsdk4'

  included do
    process_api_features_support
  end

  def supported_features
    @supported_features ||= supported_api_versions.collect { |version| self.class.api_features[version.to_s] }.flatten.uniq
  end

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])
    version = options[:version] || highest_supported_api_version || 3
    unless options[:skip_supported_api_validation] || supports_the_api_version?(version)
      raise "version #{version} of the api is not supported by the provider"
    end

    # If the API path is stored in the endpoints table then use it:
    path = options[:path] || default_endpoint.path
    _log.info("Using stored API path '#{path}'.") unless path.blank?

    # Prepare the options to call the method that creates the actual connection:
    connect_options = {
      :scheme     => options[:scheme] || 'https',
      :server     => options[:ip] || address,
      :port       => options[:port] || self.port,
      :path       => path,
      :username   => options[:user] || authentication_userid(options[:auth_type]),
      :password   => options[:pass] || authentication_password(options[:auth_type]),
      :service    => options[:service] || "Service",
      :verify_ssl => default_endpoint.verify_ssl,
      :ca_certs   => default_endpoint.certificate_authority
    }
    # Starting with version 4 of oVirt authentication doesn't work when using directly the IP address, it requires
    # the fully qualified host name, so if we received an IP address we try to convert it into the corresponding
    # host name:
    if resolve_ip_addresses?
      resolved = resolve_ip_address(connect_options[:server])
      if resolved != connect_options[:server]
        _log.info("IP address '#{connect_options[:server]}' has been resolved to host name '#{resolved}'.")
        default_endpoint.hostname = resolved
        connect_options[:server] = resolved
      end
    end

    # Create the underlying connection according to the version of the oVirt API requested by
    # the caller:
    connect_method = "raw_connect_v#{version}".to_sym
    connection = self.class.public_send(connect_method, connect_options)

    # Copy the API path to the endpoints table:
    default_endpoint.path = version.to_i == 4 ? '/ovirt-engine/api' : connection.api_path

    connection
  end

  def supports_port?
    true
  end

  def supported_api_versions
    supported_api_versions_from_cache
  end

  def supported_api_versions_from_cache
    cacher = Cacher.new(cache_key)
    current_cache_val = cacher.read
    force = current_cache_val.blank?
    cacher.fetch_fresh(last_refresh_date, :force => force) { supported_api_versions_from_sdk }
  end

  def cache_key
    "REDHAT_EMS_CACHE_KEY_#{id}"
  end

  def supported_api_versions_from_sdk
    username = authentication_userid(:basic)
    password = authentication_password(:basic)
    probe_args = { :host => hostname, :port => port, :username => username, :password => password, :insecure => true }
    probe_results = OvirtSDK4::Probe.probe(probe_args)
    probe_results.map(&:version) if probe_results
  rescue => error
    _log.error("Error while probing supported api versions #{error}")
    []
  end

  def supports_the_api_version?(version)
    supported_api_versions.map(&:to_s).include?(version.to_s)
  end

  def supported_auth_types
    %w(default metrics)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  def rhevm_service
    @rhevm_service ||= connect(:service => "Service")
  end

  def rhevm_inventory
    @rhevm_inventory ||= connect(:service => "Inventory")
  end

  def inventory
    ManageIQ::Providers::Redhat::InfraManager::Inventory::Builder.new(self)
                                                                 .build.new(:ems => self)
  end

  def with_provider_connection(options = {})
    raise "no block given" unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{name}]")
    begin
      connection = connect(options)
      yield connection
    ensure
      # The `connect` method will return different types of objects depending on the value of the `version`
      # parameter. If `version` is 3 the connection object is created by the `ovirt` gem and it is closed
      # using the `disconnect` method. If `version` is 4 the object is created by the oVirt Ruby SDK, and
      # it is closed using the `close` method.
      begin
        if connection.respond_to?(:disconnect)
          connection.disconnect
        elsif connection.respond_to?(:close)
          connection.close
        end
      rescue => error
        _log.error("Error while disconnecting #{error}")
        nil
      end
    end
  end

  def verify_credentials_for_rhevm(options = {})
    require 'ovirt'
    with_provider_connection(options) { |connection| connection.test(true) }
  rescue SocketError, Errno::EHOSTUNREACH, Errno::ENETUNREACH
    _log.warn($ERROR_INFO)
    raise MiqException::MiqUnreachableError, $ERROR_INFO
  rescue Ovirt::MissingResourceError, URI::InvalidURIError
    raise MiqException::MiqUnreachableError, "Invalid URI specified for the server."
  rescue RestClient::Unauthorized
    raise MiqException::MiqInvalidCredentialsError, "Incorrect user name or password."
  rescue
    _log.error("Error while verifying credentials #{$ERROR_INFO}")
    raise MiqException::MiqEVMLoginError, $ERROR_INFO
  end

  def rhevm_metrics_connect_options(options = {})
    metrics_hostname = connection_configuration_by_role('metrics')
      .try(:endpoint)
      .try(:hostname)
    server   = options[:hostname] || metrics_hostname || hostname
    username = options[:user] || authentication_userid(:metrics)
    password = options[:pass] || authentication_password(:metrics)
    database = options[:database] || history_database_name

    {
      :host     => server,
      :database => database,
      :username => username,
      :password => password
    }
  end

  def verify_credentials_for_rhevm_metrics(options = {})
    require 'ovirt_metrics'
    OvirtMetrics.connect(rhevm_metrics_connect_options(options))
    OvirtMetrics.connected?
  rescue PGError => e
    message = (e.message.starts_with?("FATAL:") ? e.message[6..-1] : e.message).strip

    case message
    when /database \".*\" does not exist/
      if database.nil? && (conn_info[:database] != OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME_3_0)
        conn_info[:database] = OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME_3_0
        retry
      end
    end

    _log.warn("PGError: #{message}")
    raise MiqException::MiqEVMLoginError, message
  rescue Exception => e
    raise MiqException::MiqEVMLoginError, e.to_s
  ensure
    OvirtMetrics.disconnect rescue nil
  end

  def authentications_to_validate
    at = [:default]
    at << :metrics if self.has_authentication_type?(:metrics)
    at
  end

  def verify_credentials(auth_type = nil, options = {})
    options[:skip_supported_api_validation] = true
    auth_type ||= 'default'
    case auth_type.to_s
    when 'default' then verify_credentials_for_rhevm(options)
    when 'metrics' then verify_credentials_for_rhevm_metrics(options)
    else;          raise "Invalid Authentication Type: #{auth_type.inspect}"
    end
  end

  def history_database_name
    connection_configurations.try(:metrics).try(:endpoint).try(:path) || self.class.default_history_database_name
  end

  # Adding disks is supported only by API version 4.0
  def with_disk_attachments_service(vm)
    with_version4_vm_service(vm) do |service|
      disk_service = service.disk_attachments_service
      yield disk_service
    end
  end

  def with_version4_vm_service(vm)
    connection = connect(:version => 4)
    service = connection.system_service.vms_service.vm_service(vm.uid_ems)
    yield service
  ensure
    connection.close
  end

  def highest_supported_api_version
    supported_api_versions.sort.last
  end

  class_methods do
    def api3_supported_features
      []
    end

    def api4_supported_features
      [
        :migrate,
        :quick_stats,
        :reconfigure_disks,
        :snapshots
      ]
    end

    def api_features
      { "3" => api3_supported_features, "4" => api4_supported_features }
    end

    def process_api_features_support
      all_features = api_features.values.flatten.uniq
      all_features.each do |feature|
        supports feature do
          unless supported_features.include?(feature)
            unsupported_reason_add(feature, _("This feature is not supported by the api version of the provider"))
          end
        end
      end
    end

    # Connect to the engine using version 4 of the API and the `ovirt-engine-sdk` gem.
    def raw_connect_v4(options = {})
      require 'ovirtsdk4'

      # Get the timeout from the configuration:
      timeout, = ems_timeouts(:ems_redhat, options[:service])

      # The constructor of the SDK expects a list of certificates, but that list can't be empty, or contain only 'nil'
      # values, so we need to check the value passed and make a list only if it won't be empty. If it will be empty then
      # we should just pass 'nil'.
      ca_certs = options[:ca_certs]
      ca_certs = [ca_certs] if ca_certs

      url = URI::Generic.build(
        :scheme => options[:scheme],
        :host   => options[:server],
        :port   => options[:port],
        :path   => options[:path] || '/ovirt-engine/api'
      )

      OvirtSDK4::Connection.new(
        :url      => url.to_s,
        :username => options[:username],
        :password => options[:password],
        :timeout  => timeout,
        :insecure => options[:verify_ssl] == OpenSSL::SSL::VERIFY_NONE,
        :ca_certs => ca_certs,
        :log      => $rhevm_log,
      )
    end

    # Connect to the engine using version 3 of the API and the `ovirt` gem.
    def raw_connect_v3(options = {})
      require 'ovirt'
      require 'ovirt_provider/inventory/ovirt_inventory'
      Ovirt.logger = $rhevm_log

      params = {
        :server     => options[:server],
        :port       => options[:port].presence && options[:port].to_i,
        :path       => options[:path],
        :username   => options[:username],
        :password   => options[:password],
        :verify_ssl => options[:verify_ssl],
        :ca_certs   => options[:ca_certs]
      }

      read_timeout, open_timeout = ems_timeouts(:ems_redhat, options[:service])
      params[:timeout]      = read_timeout if read_timeout
      params[:open_timeout] = open_timeout if open_timeout
      const = options[:service] == "Inventory" ? OvirtInventory : Ovirt.const_get(options[:service])
      conn = const.new(params)
      DecorateOvirtConnection.new(conn)
    end

    class DecorateOvirtConnection < SimpleDelegator
      def test(_raise_exceptions)
        api
      end
    end

    def default_history_database_name
      require 'ovirt_metrics'
      OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME
    end

    # Calculates an "ems_ref" from the "href" attribute provided by the oVirt REST API, removing the
    # "/ovirt-engine/" prefix, as for historic reasons the "ems_ref" stored in the database does not
    # contain it, it only contains the "/api" prefix which was used by older versions of the engine.
    def make_ems_ref(href)
      href && href.sub(%r{^/ovirt-engine/}, '/')
    end

    def extract_ems_ref_id(href)
      href && href.split("/").last
    end
  end

  class Cacher
    attr_reader :key

    def initialize(key)
      @key = key
    end

    def fetch_fresh(last_refresh_time, options)
      force = options[:force] || stale_cache?(last_refresh_time)
      res = Rails.cache.fetch(key, force: force) { build_entry { yield } }
      res[:value]
    end

    def read
      res = Rails.cache.read(key)
      res && res[:value]
    end

    private

    def build_entry
      {:created_at => Time.now.utc, :value => yield}
    end

    def stale_cache?(last_refresh_time)
      current_val = Rails.cache.read(key)
      return true unless current_val && current_val[:created_at] && last_refresh_time
      last_refresh_time > current_val[:created_at]
    end
  end

  private

  #
  # Checks if IP address to host name resolving is enabled.
  #
  # @return [Boolean] `true` if host name resolving is enabled in the configuration, `false` otherwise.
  #
  def resolve_ip_addresses?
    ::Settings.ems.ems_redhat.resolve_ip_addresses
  end

  #
  # Tries to convert the given IP address into a host name, doing a reverse DNS lookup if needed. If it
  # isn't possible to find the host name the original IP address will be returned, and a warning will be
  # written to the log.
  #
  # @param address [String] The IP address.
  # @return [String] The host name.
  #
  def resolve_ip_address(address)
    # Don't try to resolve unless the string is really an IP address and not a host name:
    return address unless address =~ Resolv::IPv4::Regex || address =~ Resolv::IPv6::Regex

    # Try to do a reverse resolve of the address to find the host name, using the default resolver, which
    # means first using the local hosts file and then DNS:
    begin
      Resolv.getname(address)
    rescue Resolv::ResolvError
      _log.warn(
        "Can't find fully qualified host name for IP address '#{address}', will use the IP address " \
        "directly."
      )
      address
    end
  end
end

module ManageIQ::Providers::Redhat::InfraManager::ApiIntegration
  extend ActiveSupport::Concern

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    # If there is API path stored in the endpoints table and use it:
    path = default_endpoint.path
    _log.info("Using stored API path '#{path}'.") unless path.blank?

    server   = options[:ip] || address
    port     = options[:port] || self.port
    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])
    service  = options[:service] || "Service"
    version  = options[:version] || 3

    # Create the underlying connection according to the version of the oVirt API requested by
    # the caller:
    connect_method = "raw_connect_v#{version}".to_sym
    connection = self.class.public_send(connect_method, server, port, path, username, password, service)

    # Copy the API path to the endpoints table:
    default_endpoint.path = version == 4 ? '/ovirt-engine/api' : connection.api_path

    connection
  end

  def supports_port?
    true
  end

  def supports_api_version?(version)
    supported_api_versions.include?(version)
  end

  def supported_auth_types
    %w(default metrics)
  end

  def rhevm_service
    @rhevm_service ||= connect(:service => "Service")
  end

  def rhevm_inventory
    @rhevm_inventory ||= connect(:service => "Inventory")
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
    with_provider_connection(options, &:api)
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
    database = options[:database]

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
    auth_type ||= 'default'

    case auth_type.to_s
    when 'default' then verify_credentials_for_rhevm(options)
    when 'metrics' then verify_credentials_for_rhevm_metrics(options)
    else;          raise "Invalid Authentication Type: #{auth_type.inspect}"
    end
  end

  def history_database_name
    @history_database_name ||= begin
      version = version_3_0? ? '3_0' : '>3_0'
      self.class.history_database_name_for(version)
    end
  end

  def version_3_0?
    if @version_3_0.nil?
      @version_3_0 =
        if api_version.nil?
          with_provider_connection(&:version_3_0?)
        else
          api_version.starts_with?("3.0")
        end
    end

    @version_3_0
  end

  # Adding disks is supported only by API version 4.0
  def with_disk_attachments_service(vm)
    connection = connect(:version => 4)
    service = connection.system_service.vms_service.vm_service(vm.uid_ems).disk_attachments_service
    yield service
  ensure
    connection.close
  end

  class_methods do
    # Connect to the engine using version 4 of the API and the `ovirt-engine-sdk` gem.
    def raw_connect_v4(server, port, path, username, password, service)
      require 'ovirtsdk4'

      # Get the timeout from the configuration:
      timeout, = ems_timeouts(:ems_redhat, service)

      # Create the connection:
      OvirtSDK4::Connection.new(
        :url      => "https://#{server}:#{port}#{path}",
        :username => username,
        :password => password,
        :timeout  => timeout,
        :insecure => true,
        :log      => $rhevm_log,
      )
    end

    # Connect to the engine using version 3 of the API and the `ovirt` gem.
    def raw_connect_v3(server, port, path, username, password, service)
      require 'ovirt'
      require 'ovirt_provider/inventory/ovirt_inventory'

      Ovirt.logger = $rhevm_log

      params = {
        :server     => server,
        :port       => port.presence && port.to_i,
        :path       => path,
        :username   => username,
        :password   => password,
        :verify_ssl => false
      }

      read_timeout, open_timeout = ems_timeouts(:ems_redhat, service)
      params[:timeout]      = read_timeout if read_timeout
      params[:open_timeout] = open_timeout if open_timeout

      const = service == "Inventory" ? OvirtInventory : Ovirt.const_get(service)
      const.new(params)
    end

    def history_database_name_for(api_version)
      require 'ovirt_metrics'
      case api_version
      when '3_0'
        OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME_3_0
      else
        OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME
      end
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
end

class ManageIQ::Providers::Redhat::InfraManager < ManageIQ::Providers::InfraManager
  require_dependency 'manageiq/providers/redhat/infra_manager/event_catcher'
  require_dependency 'manageiq/providers/redhat/infra_manager/event_parser'
  require_dependency 'manageiq/providers/redhat/infra_manager/refresh_worker'
  require_dependency 'manageiq/providers/redhat/infra_manager/refresh_parser'
  require_dependency 'manageiq/providers/redhat/infra_manager/metrics_collector_worker'
  require_dependency 'manageiq/providers/redhat/infra_manager/host'
  require_dependency 'manageiq/providers/redhat/infra_manager/provision'
  require_dependency 'manageiq/providers/redhat/infra_manager/provision_via_iso'
  require_dependency 'manageiq/providers/redhat/infra_manager/provision_via_pxe'
  require_dependency 'manageiq/providers/redhat/infra_manager/provision_workflow'
  require_dependency 'manageiq/providers/redhat/infra_manager/refresher'
  require_dependency 'manageiq/providers/redhat/infra_manager/template'
  require_dependency 'manageiq/providers/redhat/infra_manager/vm'

  def self.ems_type
    @ems_type ||= "rhevm".freeze
  end

  def self.description
    @description ||= "Red Hat Enterprise Virtualization Manager".freeze
  end

  def self.default_blacklisted_event_names
    %w(
      UNASSIGNED
      USER_REMOVE_VG
      USER_REMOVE_VG_FAILED
      USER_VDC_LOGIN
      USER_VDC_LOGOUT
      USER_VDC_LOGIN_FAILED
    )
  end

  def supports_port?
    true
  end

  def supported_auth_types
    %w(default metrics)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  def self.raw_connect(server, port, username, password, service = "Service")
    require 'ovirt'
    Ovirt.logger = $rhevm_log

    params = {
      :server     => server,
      :port       => port.presence && port.to_i,
      :username   => username,
      :password   => password,
      :verify_ssl => false
    }

    read_timeout, open_timeout = ems_timeouts(:ems_redhat, service)
    params[:timeout]      = read_timeout if read_timeout
    params[:open_timeout] = open_timeout if open_timeout

    Ovirt.const_get(service).new(params)
  end

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    server   = options[:ip]      || self.address
    port     = options[:port]    || self.port
    username = options[:user]    || self.authentication_userid(options[:auth_type])
    password = options[:pass]    || self.authentication_password(options[:auth_type])
    service  = options[:service] || "Service"

    self.class.raw_connect(server, port, username, password, service)
  end

  def rhevm_service
    @rhevm_service ||= connect(:service => "Service")
  end

  def rhevm_inventory
    @rhevm_inventory ||= connect(:service => "Inventory")
  end

  def with_provider_connection(options = {})
    raise "no block given" unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{self.name}]")
    begin
      connection = self.connect(options)
      yield connection
    ensure
      connection.try(:disconnect) rescue nil
    end
  end

  def verify_credentials_for_rhevm(options={})
    begin
      connect(options).api
    rescue URI::InvalidURIError
      raise "Invalid URI specified for RHEV server."
    rescue => err
      err = err.to_s.split('<html>').first.strip.chomp(':')
      raise MiqException::MiqEVMLoginError, err
    end
  end

  def rhevm_metrics_connect_options(options = {})
    server   = options[:hostname] || hostname
    username = options[:user]     || authentication_userid(:metrics)
    password = options[:pass]     || authentication_password(:metrics)
    database = options[:database]

    {
      :host     => server,
      :database => database,
      :username => username,
      :password => password
    }
  end

  def verify_credentials_for_rhevm_metrics(options = {})
    begin
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
  end

  def authentications_to_validate
    at = [:default]
    at << :metrics if self.has_authentication_type?(:metrics)
    at
  end

  def verify_credentials(auth_type=nil, options={})
    auth_type ||= 'default'

    case auth_type.to_s
    when 'default'; verify_credentials_for_rhevm(options)
    when 'metrics'; verify_credentials_for_rhevm_metrics(options)
    else;          raise "Invalid Authentication Type: #{auth_type.inspect}"
    end
  end

  def self.event_monitor_class
    self::EventCatcher
  end

  def self.provision_class(via)
    case via
    when "iso" then self::ProvisionViaIso
    when "pxe" then self::ProvisionViaPxe
    else            self::Provision
    end
  end

  def history_database_name
    @history_database_name ||= begin
      require 'ovirt_metrics'
      version_3_0? ? OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME_3_0 : OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME
    end
  end

  def version_3_0?
    if @version_3_0.nil?
      @version_3_0 =
        if self.api_version.nil?
          self.with_provider_connection(&:version_3_0?)
        else
          self.api_version.starts_with?("3.0")
        end
    end

    @version_3_0
  end
end

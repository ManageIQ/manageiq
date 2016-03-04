class ManageIQ::Providers::Oracle::InfraManager < ManageIQ::Providers::InfraManager
  require_nested :RefreshWorker
  require_nested :RefreshParser
  require_nested :Host
  require_nested :Refresher
  require_nested :Template
  require_nested :Vm

  def self.ems_type
    @ems_type ||= "oraclevm".freeze
  end

  def self.description
    @description ||= "Oracle Virtualization Manager".freeze
  end

  def self.default_blacklisted_event_names
    []
  end

  def supports_port?
    true
  end

  def supported_auth_types
    %w(default)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  def self.raw_connect(server, port, username, password)
    require 'fog/oracle'

    url = "https://#{server}:#{port}"

    params = {
      :oracle_username => username,
      :oracle_password => password,
      :oracle_url      => url,
      :connection_options => {
        :ciphers => 'HIGH:RC4:!SSLv2:!aNULL:!eNULL:!3DES',
        :ssl_verify_peer => false
      }
    }

    Fog::Compute::Oracle.new(params)
  end

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    server   = options[:ip] || address
    port     = options[:port] || self.port
    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])

    self.class.raw_connect(server, port, username, password)
  end

  def oraclevm_service
    @oraclevm_service ||= connect
  end

  def with_provider_connection(options = {})
    raise "no block given" unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{name}]")
    begin
      connection = connect(options)
      yield connection
    ensure
      connection.try(:disconnect) rescue nil
    end
  end

  def verify_credentials_for_oraclevm(options = {})
    connect(options).login
  rescue URI::InvalidURIError
    raise "Invalid URI specified for Oracle server."
  rescue => err
    err = err.to_s.split('<html>').first.strip.chomp(':')
    raise MiqException::MiqEVMLoginError, err
  end

  def authentications_to_validate
    [:default]
  end

  def verify_credentials(auth_type = nil, options = {})
    auth_type ||= 'default'

    case auth_type.to_s
    when 'default' then verify_credentials_for_oraclevm(options)
    else;          raise "Invalid Authentication Type: #{auth_type.inspect}"
    end
  end
end

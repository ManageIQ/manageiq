class ManageIQ::Providers::Nuage::NetworkManager < ManageIQ::Providers::NetworkManager
  include SupportsFeatureMixin
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :VsdClient
  supports :ems_network_new

  include Vmdb::Logging

  def self.ems_type
    @ems_type ||= "nuage_network".freeze
  end

  def self.description
    @description ||= "Nuage Network Manager".freeze
  end

  def self.raw_connect(auth_url, username, password)
    VsdClient.new(auth_url, username, password)
  end

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    protocol = options[:protocol] || security_protocol
    server   = options[:ip] || address
    port     = options[:port] || self.port
    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])
    version  = options[:version] || api_version

    url = auth_url(protocol, server, port, version)
    _log.info("Connecting to Nuage VSD with url #{url}")
    self.class.raw_connect(url, username, password)
  end

  def translate_exception(err)
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

  def verify_credentials(auth_type = nil, options = {})
    auth_type ||= 'default'

    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(auth_type)

    options[:auth_type] = auth_type
    with_provider_connection(options) {}
    true

  rescue => err
    miq_exception = translate_exception(err)
    raise unless miq_exception

    _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    raise miq_exception
  end

  def auth_url(protocol, server, port, version)
    scheme = protocol == "ssl-with-validation" ? "https" : "http"
    "#{scheme}://#{server}:#{port}/nuage/api/#{version}"
  end
end

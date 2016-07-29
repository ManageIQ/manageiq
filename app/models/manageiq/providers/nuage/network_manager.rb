class ManageIQ::Providers::Nuage::NetworkManager < ManageIQ::Providers::NetworkManager
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :VsdClient

  def self.ems_type
    @ems_type ||= "nuage".freeze
  end

  def self.description
    @description ||= "Nuage Networks".freeze
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
    $log.info("Connecting to Nuage VSD with url #{url}")
    self.class.raw_connect(url, username, password)
  end

  def auth_url(protocol, server, port, version)
    scheme = protocol == "no_ssl" ? "http" : "https"
    scheme + '://' + server + ':' + port.to_s + '/' + 'nuage/api/' + version
  end
end

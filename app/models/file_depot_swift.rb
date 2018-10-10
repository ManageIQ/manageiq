class FileDepotSwift < FileDepot
  def self.uri_prefix
    "swift"
  end

  def self.validate_settings(settings)
    new(:uri => settings[:uri]).verify_credentials(nil, settings.slice(:username, :password))
  end

  def connect(options = {})
    openstack_handle(options).connect(options)
  end

  def openstack_handle(options = {})
    require 'manageiq/providers/openstack/legacy/openstack_handle'
    @openstack_handle ||= begin
      username = options[:username] || authentication_userid(options[:auth_type])
      password = options[:password] || authentication_password(options[:auth_type])
      uri      = options[:uri]
      address  = URI(uri).host
      port     = URI(uri).port

      extra_options = {
        :ssl_ca_file    => ::Settings.ssl.ssl_ca_file,
        :ssl_ca_path    => ::Settings.ssl.ssl_ca_path,
        :ssl_cert_store => OpenSSL::X509::Store.new
      }
      extra_options[:domain_id]         = v3_domain_ident
      extra_options[:service]           = "Compute"
      extra_options[:omit_default_port] = ::Settings.ems.ems_openstack.excon.omit_default_port
      extra_options[:read_timeout]      = ::Settings.ems.ems_openstack.excon.read_timeout
      begin
        OpenstackHandle::Handle.new(username, password, address, port, keystone_api_version, security_protocol, extra_options)
      rescue => err
        msg = "Error connecting to Swift host #{address}. #{err}"
        logger.error(msg)
        raise err, msg, err.backtrace
      end
    end
  end

  def verify_credentials(auth_type = 'default', options = {})
    host = URI(options[:uri]).host
    options[:auth_type] = auth_type
    connect(options.merge(:auth_type => auth_type))
  rescue Excon::Errors::Unauthorized => err
    msg = "Access to Swift host #{host} failed due to a bad username or password."
    logger.error("#{msg} #{err}")
    raise msg
  rescue => err
    msg = "Error connecting to Swift host #{host}. #{err}"
    logger.error(msg)
    raise err, msg, err.backtrace
  end

  def merged_uri(uri, api_port)
    uri            = URI(uri)
    uri.port       = api_port.presence || 5000
    query_elements = []
    query_elements << "region=#{openstack_region}"              if openstack_region.present?
    query_elements << "api_version=#{keystone_api_version}"     if keystone_api_version.present?
    query_elements << "domain_id=#{v3_domain_ident}"            if v3_domain_ident.present?
    query_elements << "security_protocol=#{security_protocol}"  if security_protocol.present?
    uri.query = query_elements.join('&').presence
    uri.to_s
  end
end

class ManageIQ::Providers::Vmware::CloudManager < ManageIQ::Providers::CloudManager
  def self.ems_type
    @ems_type ||= "vmware_cloud".freeze
  end

  def self.description
    @description ||= "VMware vCloud".freeze
  end

  def self.default_blacklisted_event_names
    []
  end

  def self.hostname_required?
    true
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

  #
  # Connections
  #

  def self.raw_connect(server, port, username, password)
    require 'fog/vcloud_director'

    params = {
      :vcloud_director_username      => username,
      :vcloud_director_password      => password,
      :vcloud_director_host          => server,
      :vcloud_director_show_progress => false,
      :port                          => port,
      :connection_options            => {
        :ssl_verify_peer => false # for development
      }
    }

    Fog::Compute::VcloudDirector.new(params)
  end

  def connect(options = {})
    raise "no credentials defined" if missing_credentials?(options[:auth_type])

    server   = options[:ip] || address
    port     = options[:port] || self.port
    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])

    self.class.raw_connect(server, port, username, password)
  end

  def translate_exception(err)
    case err
    when Fog::Compute::VcloudDirector::Unauthorized
      MiqException::MiqInvalidCredentialsError.new "Login failed due to a bad username or password."
    else
      MiqException::MiqHostError.new "Unexpected response returned from system: #{err.message}"
    end
  end

  def verify_credentials(auth_type = nil, options = {})
    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(auth_type)

    begin
      with_provider_connection(options.merge(:auth_type => auth_type)) do |vcd|
        vcd.organizations.all
      end
    rescue => err
      miq_exception = translate_exception(err)

      _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
      raise miq_exception
    end

    true
  end
end

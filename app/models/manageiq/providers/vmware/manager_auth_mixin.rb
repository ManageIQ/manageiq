require 'fog/vcloud_director'

module ManageIQ::Providers::Vmware::ManagerAuthMixin
  extend ActiveSupport::Concern

  def verify_credentials(auth_type = nil, options = {})
    auth_type ||= 'default'
    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(auth_type)

    options[:auth_type] = auth_type
    begin
      case auth_type.to_s
      when 'default' then
        with_provider_connection(options) do |vcd|
          vcd.organizations.all
        end
      when 'amqp' then
        verify_amqp_credentials(options)
      else
        raise "Invalid Vmware vCloud Authentication Type: #{auth_type.inspect}"
      end
    rescue => err
      miq_exception = translate_exception(err)
      _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
      raise miq_exception
    end

    true
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
    when Excon::Errors::Timeout
      MiqException::MiqUnreachableError.new "Login attempt timed out"
    when Excon::Errors::SocketError
      MiqException::MiqHostError.new "Socket error: #{err.message}"
    when MiqException::MiqInvalidCredentialsError, MiqException::MiqHostError
      err
    else
      MiqException::MiqHostError.new "Unexpected response returned from system: #{err.message}"
    end
  end

  module ClassMethods
    def raw_connect(server, port, username, password)
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
  end
end

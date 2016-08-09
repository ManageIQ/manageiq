module ManageIQ::Providers::Vmware::ManagerAuthMixin
  extend ActiveSupport::Concern

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

  def connect(options = {})
    raise "no credentials defined" if missing_credentials?(options[:auth_type])

    server   = options[:ip] || address
    port     = options[:port] || self.port
    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])

    self.class.raw_connect(server, port, username, password)
  end

  module ClassMethods
    def raw_connect(server, port, username, password)
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
  end
end

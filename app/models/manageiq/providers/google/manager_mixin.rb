module ManageIQ::Providers::Google::ManagerMixin
  extend ActiveSupport::Concern

  def verify_credentials(auth_type = nil, options = {})
    begin
      options[:auth_type] = auth_type

      connection = connect(options)

      # Not all errors will cause Fog to raise an exception,
      # for example an error in the google_project id will
      # succeed to connect but the first API call will raise
      # an exception, so make a simple call to the API to
      # confirm everything is working
      connection.regions.all
    rescue => err
      raise MiqException::MiqInvalidCredentialsError, err.message
    end

    true
  end

  def connect(options = {})
    require 'fog/google'

    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(options[:auth_type])

    auth_token = authentication_token(options[:auth_type])
    self.class.raw_connect(project, auth_token, options, options[:proxy_uri] || http_proxy_uri)
  end

  def gce
    @gce ||= connect(:service => "compute")
  end

  module ClassMethods
    def raw_connect(google_project, google_json_key, options, proxy_uri = nil)
      require 'fog/google'

      config = {
        :provider               => "Google",
        :google_project         => google_project,
        :google_json_key_string => google_json_key,
        :app_name               => I18n.t("product.name"),
        :app_version            => Vmdb::Appliance.VERSION,
        :google_client_options  => {
          :proxy => proxy_uri
        }
      }

      case options[:service]
      # specify Compute as the default
      when 'compute', nil
        ::Fog::Compute.new(config)
      when 'pubsub'
        ::Fog::Google::Pubsub.new(config.except(:provider))
      when 'monitoring'
        ::Fog::Google::Monitoring.new(config.except(:provider))
      else
        raise ArgumentError, "Unknown service: #{options[:service]}"
      end
    end
  end
end

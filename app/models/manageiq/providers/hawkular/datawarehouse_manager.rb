module ManageIQ::Providers
  class Hawkular::DatawarehouseManager < ManageIQ::Providers::DatawarehouseManager
    require 'hawkular/hawkular_client'

    require_nested :RefreshParser
    require_nested :RefreshWorker
    require_nested :Refresher

    include AuthenticationMixin

    DEFAULT_PORT = 80
    default_value_for :port do |provider|
      provider.port || DEFAULT_PORT
    end

    def verify_credentials(_auth_type = nil, options = {})
      connect(options).fetch_version_and_status
    rescue URI::InvalidComponentError
      raise MiqException::MiqHostError, "Host '#{hostname}' is invalid"
    rescue ::Hawkular::BaseClient::HawkularConnectionException
      raise MiqException::MiqUnreachableError, "Unable to connect to #{hostname}:#{port}"
    rescue ::Hawkular::BaseClient::HawkularException => he
      raise MiqException::MiqInvalidCredentialsError, 'Invalid credentials' if he.status_code == 401
      raise MiqException::MiqHostError, 'Hawkular not found on host' if he.status_code == 404
      raise MiqException::MiqCommunicationsError, he.message
    rescue => err
      $log.error(err)
      raise MiqException::Error, 'Unable to verify credentials'
    end

    def validate_authentication_status
      {:available => true, :message => nil}
    end

    def self.verify_ssl_mode
      # TODO: support real authentication using certificates
      OpenSSL::SSL::VERIFY_NONE
    end

    # Hawkular Client
    def self.raw_connect(hostname, port, token, type)
      type ||= :alerts
      klass = case type
              when :metrics
                ::Hawkular::Metrics::Client
              when :alerts
                ::Hawkular::Alerts::AlertsClient
              else
                raise ArgumentError, "Client not found for #{type}"
              end
      klass.new(
        URI::HTTPS.build(:host => hostname, :port => port.to_i).to_s,
        { :token => token },
        { :tenant => '_system', :verify_ssl => verify_ssl_mode }
      )
    end

    def connect(options = {})
      @clients ||= {}
      @clients[options[:type]] ||= self.class.raw_connect(
        hostname,
        port,
        authentication_token('default'),
        options[:type]
      )
    end

    def alerts_client
      connect(:type => :alerts)
    end

    def metrics_client
      connect(:type => :metrics)
    end

    def supports_port?
      true
    end

    def supported_auth_types
      %w(default auth_key)
    end

    def required_credential_fields(_type)
      [:auth_key]
    end

    def supports_authentication?(authtype)
      supported_auth_types.include?(authtype.to_s)
    end

    def default_authentication_type
      :default
    end

    def self.ems_type
      @ems_type ||= "hawkular_datawarehouse".freeze
    end

    def self.description
      @description ||= "Hawkular Datawarehouse".freeze
    end
  end
end

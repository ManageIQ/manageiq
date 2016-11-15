module ManageIQ::Providers
  class Hawkular::DatawarehouseManager < ManageIQ::Providers::DatawarehouseManager
    require 'hawkular/hawkular_client'

    require_nested :RefreshParser
    require_nested :RefreshWorker
    require_nested :Refresher

    include AuthenticationMixin

    DEFAULT_PORT = 80
    default_value_for :port, DEFAULT_PORT

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

    def self.verify_ssl_mode
      # TODO: support real authentication using certificates
      OpenSSL::SSL::VERIFY_NONE
    end

    # Hawkular Client
    def self.raw_connect(hostname, port, token, alerts = false)
      client = alerts ? ::Hawkular::Alerts::AlertsClient : ::Hawkular::Metrics::Client
      client.new(
        URI::HTTPS.build(:host => hostname, :port => port.to_i).to_s,
        { :token => token },
        { :tenant => '_system', :verify_ssl => verify_ssl_mode }
      )
    end

    def connect(options = {})
      @client ||= self.class.raw_connect(hostname,
                                         port,
                                         authentication_token('default'),
                                         options[:alerts])
    end

    def supports_port?
      true
    end

    def supported_auth_types
      %w(default bearer)
    end

    def supports_authentication?(authtype)
      supported_auth_types.include?(authtype.to_s)
    end

    def default_authentication_type
      :bearer
    end

    def self.ems_type
      @ems_type ||= "hawkular_datawarehouse".freeze
    end

    def self.description
      @description ||= "Hawkular Datawarehouse".freeze
    end
  end
end

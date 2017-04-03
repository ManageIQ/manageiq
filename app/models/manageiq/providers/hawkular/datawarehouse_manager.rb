module ManageIQ::Providers
  class Hawkular::DatawarehouseManager < ManageIQ::Providers::DatawarehouseManager
    require 'openssl'
    require 'hawkular/hawkular_client'

    require_nested :EventCatcher
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

    def verify_ssl_mode(endpoint = default_endpoint)
      case endpoint.security_protocol
      when 'ssl-without-validation'
        OpenSSL::SSL::VERIFY_NONE
      else # 'ssl-with-validation', 'ssl-with-validation-custom-ca', secure by default with unexpected values.
        OpenSSL::SSL::VERIFY_PEER
      end
    end

    # Hawkular Client
    def self.raw_connect(options)
      type = options[:type] || :alerts
      tenant = options[:tenant] || '_system'
      klass = case type
              when :metrics
                ::Hawkular::Metrics::Client
              when :alerts
                ::Hawkular::Alerts::Client
              else
                raise ArgumentError, "Client not found for [#{type}]"
              end
      klass.new(
        URI::HTTPS.build(:host => options[:hostname], :port => options[:port].to_i).to_s,
        { :token => options[:token] },
        { :tenant => tenant, :verify_ssl => options[:verify_ssl], :ssl_cert_store => options[:ssl_cert_store] }
      )
    end

    def connect(options = {})
      @clients ||= {}
      memo_options = options.slice(:type, :tenant)
      @clients[memo_options.freeze] ||= self.class.raw_connect(
        memo_options.merge(
          :hostname       => hostname,
          :port           => port,
          :token          => authentication_token('default'),
          :verify_ssl     => verify_ssl_mode,
          :ssl_cert_store => default_endpoint.ssl_cert_store
        )
      )
    end

    def alerts_client(options = {})
      connect(options.merge(:type => :alerts))
    end

    def metrics_client(options = {})
      connect(options.merge(:type => :metrics))
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

    def self.event_monitor_class
      ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher
    end
  end
end

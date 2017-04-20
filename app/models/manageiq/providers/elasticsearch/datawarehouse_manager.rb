module ManageIQ::Providers
  class Elasticsearch::DatawarehouseManager < ManageIQ::Providers::DatawarehouseManager
    require 'elasticsearch'

    require_nested :RefreshParser
    require_nested :RefreshWorker
    require_nested :Refresher

    include AuthenticationMixin

    DEFAULT_PORT = 443
    default_value_for :port, DEFAULT_PORT

    def verify_credentials(_auth_type = nil, options = {})
      connect(options).info
    rescue URI::InvalidComponentError
      raise MiqException::MiqHostError, "Host '#{hostname}' is invalid"
    rescue ::Faraday::Error => e
      raise MiqException::MiqUnreachableError, "Unable to connect to #{hostname}:#{port}. Error: #{e.message}"
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

    def transport_options
      opts = { :ssl => { :verify_mode => self.class.verify_ssl_mode } }
      if has_authentication_type?(:cert_auth)
        cert_auth = authentication_type("cert_auth")
        opts[:ssl][:client_cert] = OpenSSL::X509::Certificate.new(cert_auth.public_key)
        opts[:ssl][:client_key] = OpenSSL::PKey::RSA.new(cert_auth.password)
      end
      opts
    end

    # Elasticsearch Client
    def self.raw_connect(hostname, port, token, options)
      scheme = token.blank? ? URI::HTTP : URI::HTTPS
      url = scheme.build(:host => hostname, :port => port)
      client = ::Elasticsearch::Client.new(
        :url               => url.to_s,
        :transport_options => options[:transport_options]
      )
      conn = client.transport.connections.first.connection
      if token
        conn.authorization(:Bearer, token)
        conn.headers['X-Forwarded-For'] = '0.0.0.0'
        # TODO: customize the user? (This is a default case when ES is run on Openshift)
        conn.headers['X-Proxy-Remote-User'] = 'system:service-account:management-infra:management-admin'
      end

      client
    end

    def connect(options = {})
      options[:transport_options] = transport_options
      @client ||= self.class.raw_connect(hostname,
                                         port,
                                         authentication_token('default'),
                                         options)
    end

    def supports_port?
      true
    end

    def supported_auth_types
      %w(default bearer cert_auth)
    end

    def required_credential_fields(_type)
      [:bearer,]
    end

    def supports_authentication?(authtype)
      supported_auth_types.include?(authtype.to_s)
    end

    def default_authentication_type
      :bearer
    end

    def self.ems_type
      @ems_type ||= "elasticsearch_datawarehouse".freeze
    end

    def self.description
      @description ||= "Elasticsearch Datawarehouse".freeze
    end
  end
end

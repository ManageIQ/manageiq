module ManageIQ::Providers
  class Hawkular::MiddlewareManager < ManageIQ::Providers::MiddlewareManager
    require_nested :MiddlewareDeployment
    require_nested :MiddlewareServer
    require_nested :RefreshParser
    require_nested :RefreshWorker
    require_nested :Refresher

    include AuthenticationMixin

    DEFAULT_PORT = 80
    default_value_for :port, DEFAULT_PORT
    has_many :middleware_servers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_deployments, :foreign_key => :ems_id, :dependent => :destroy

    def verify_credentials(_auth_type = nil, options = {})
      begin

        # As the connect will only give a handle
        # we verify the credentials via an actual operation
        connect(options).list_feeds
      rescue => err
        raise MiqException::MiqInvalidCredentialsError, err.message
      end

      true
    end

    def self.raw_connect(hostname, port, username, password)
      require 'hawkular_all'
      url = URI::HTTP.build(:host => hostname, :port => port.to_i, :path => '/hawkular/inventory').to_s
      ::Hawkular::Inventory::InventoryClient.new(url, :username => username, :password => password)
    end

    def connect(_options = {})
      self.class.raw_connect(hostname,
                             port,
                             authentication_userid('default'),
                             authentication_password('default'))
    end

    def feeds
      with_provider_connection(&:list_feeds)
    end

    def eaps(feed)
      with_provider_connection do |connection|
        connection.list_resources_for_type(feed, 'WildFly Server', true)
      end
    end

    def child_resources(eap_parent)
      with_provider_connection do |connection|
        connection.list_child_resources(eap_parent)
      end
    end

    def metrics_resource(resource)
      with_provider_connection do |connection|
        connection.list_metrics_for_resource(resource)
      end
    end

    def self.raw_metrics_connect(hostname, port, username, password)
      require 'hawkular_all'
      url = URI::HTTP.build(:host => hostname, :port => port.to_i, :path => '/hawkular/metrics').to_s
      options = {}
      credentials = {
        :username => username,
        :password => password
      }
      ::Hawkular::Metrics::Client.new(url, credentials, options)
    end

    def metrics_connect
      self.class.raw_metrics_connect(hostname,
                                     port,
                                     authentication_userid('default'),
                                     authentication_password('default'))
    end

    # UI methods for determining availability of fields
    def supports_port?
      true
    end

    def self.ems_type
      @ems_type ||= "hawkular".freeze
    end

    def self.description
      @description ||= "Hawkular".freeze
    end
  end
end

# TODO: remove the module and just make this:
# class ManageIQ::Providers::Hawkular::MiddlewareManager < ManageIQ::Providers::MiddlewareManager
module ManageIQ::Providers
  class Hawkular::MiddlewareManager < ManageIQ::Providers::MiddlewareManager
    require_nested :EventCatcher
    require_nested :LiveMetricsCapture
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

    # Inventory

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
      url         = URI::HTTP.build(:host => hostname, :port => port.to_i, :path => '/hawkular/metrics').to_s
      options     = {}
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

    def self.raw_operations_connect(hostname, port, username, password)
      require 'hawkular_all'
      host_port = URI::HTTP.build(:host => hostname, :port => port.to_i).to_s
      host_port.sub!('http://', '') # Api can't internally deal with the schema
      credentials = {:username => username, :password => password}
      ::Hawkular::Operations::OperationsClient.new(:host => host_port, :credentials => credentials)
    end

    def operations_connect
      self.class.raw_operations_connect(hostname,
                                        port,
                                        authentication_userid('default'),
                                        authentication_password('default'))
    end

    def reload_middleware_server(ems_ref)
      run_generic_operation(:Reload, ems_ref)
    end

    def stop_middleware_server(ems_ref)
      run_generic_operation(:Shutdown, ems_ref)
    end

    def self.raw_alerts_connect(hostname, port, username, password)
      require 'hawkular_all'
      url         = URI::HTTP.build(:host => hostname, :port => port.to_i, :path => '/hawkular/alerts').to_s
      credentials = {
        :username => username,
        :password => password
      }
      ::Hawkular::Alerts::AlertsClient.new(url, credentials)
    end

    def alerts_connect
      self.class.raw_alerts_connect(hostname,
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

    def self.event_monitor_class
      ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher
    end

    # To blacklist defined event types by default add them here...
    def self.default_blacklisted_event_names
      %w(
      )
    end

    private

    # Trigger running a (Hawkular) operation on the
    # selected target server. This server is identified
    # by ems_ref, which in Hawkular terms is the
    # fully qualified resource path from Hawkular inventory
    def run_generic_operation(operation, ems_ref)
      client = operations_connect

      the_operation = {
        :operationName => operation,
        :resourcePath  => ems_ref.to_s
      }

      actual_data = {}
      client.invoke_generic_operation(the_operation) do |on|
        on.success do |data|
          _log.debug "Success on websocket-operation #{data}"
          actual_data[:data] = data
        end
        on.failure do |error|
          actual_data[:data]  = {}
          actual_data[:error] = error
          _log.error 'error callback was called, reason: ' + error.to_s
        end
      end
    end
  end
end

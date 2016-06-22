# TODO: remove the module and just make this:
# class ManageIQ::Providers::Hawkular::MiddlewareManager < ManageIQ::Providers::MiddlewareManager
module ManageIQ::Providers
  class Hawkular::MiddlewareManager < ManageIQ::Providers::MiddlewareManager
    require 'hawkular/hawkular_client'

    require_nested :EventCatcher
    require_nested :LiveMetricsCapture
    require_nested :MiddlewareDeployment
    require_nested :MiddlewareDatasource
    require_nested :MiddlewareServer
    require_nested :RefreshParser
    require_nested :RefreshWorker
    require_nested :Refresher

    include AuthenticationMixin
    include ::HawkularUtilsMixin

    DEFAULT_PORT = 80
    default_value_for :port, DEFAULT_PORT

    has_many :middleware_servers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_deployments, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_datasources, :foreign_key => :ems_id, :dependent => :destroy

    attr_accessor :client

    def verify_credentials(_auth_type = nil, options = {})
      begin
        # As the connect will only give a handle
        # we verify the credentials via an actual operation
        connect(options).inventory.list_feeds
      rescue => err
        raise MiqException::MiqInvalidCredentialsError, 'Invalid credentials'
      end

      true
    end

    # Hawkular Client
    def self.raw_connect(hostname, port, username, password)
      entrypoint = URI::HTTP.build(:host => hostname, :port => port.to_i).to_s
      credentials = {
        :username => username,
        :password => password
      }
      options = {
        :tenant => 'hawkular'
      }
      ::Hawkular::Client.new(:entrypoint => entrypoint, :credentials => credentials, :options => options)
    end

    def connect(_options = {})
      @client ||= self.class.raw_connect(hostname,
                                         port,
                                         authentication_userid('default'),
                                         authentication_password('default'))
    end

    def feeds
      with_provider_connection do |connection|
        connection.inventory.list_feeds
      end
    end

    def eaps(feed)
      with_provider_connection do |connection|
        path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id          => feed,
                                                        :resource_type_id => hawk_escape_id('WildFly Server'))
        connection.inventory.list_resources_for_type(path.to_s, :fetch_properties => true)
      end
    end

    def child_resources(resource_path)
      with_provider_connection do |connection|
        connection.inventory.list_child_resources(resource_path)
      end
    end

    def metrics_resource(resource_path)
      with_provider_connection do |connection|
        connection.inventory.list_metrics_for_resource(resource_path)
      end
    end

    def metrics_client
      with_provider_connection(&:metrics)
    end

    def inventory_client
      with_provider_connection(&:inventory)
    end

    def operations_client
      with_provider_connection(&:operations)
    end

    def alerts_client
      with_provider_connection(&:alerts)
    end

    def reload_middleware_server(ems_ref)
      run_generic_operation(:Reload, ems_ref)
    end

    def stop_middleware_server(ems_ref)
      run_generic_operation(:Shutdown, ems_ref)
    end

    def undeploy_middleware_deployment(ems_ref)
      run_generic_operation(:Undeploy, ems_ref)
    end

    def redeploy_middleware_deployment(ems_ref)
      run_generic_operation(:Redeploy, ems_ref)
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
      with_provider_connection do |connection|
        the_operation = {
          :operationName => operation,
          :resourcePath  => ems_ref.to_s
        }

        actual_data = {}
        connection.operations(true).invoke_generic_operation(the_operation) do |on|
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
end

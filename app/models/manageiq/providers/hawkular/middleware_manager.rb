# TODO: remove the module and just make this:
# class ManageIQ::Providers::Hawkular::MiddlewareManager < ManageIQ::Providers::MiddlewareManager
module ManageIQ::Providers
  class Hawkular::MiddlewareManager < ManageIQ::Providers::MiddlewareManager
    require 'hawkular/hawkular_client'

    require_nested :AlertManager
    require_nested :AlertProfileManager
    require_nested :EventCatcher
    require_nested :LiveMetricsCapture
    require_nested :MiddlewareDeployment
    require_nested :MiddlewareDatasource
    require_nested :MiddlewareMessaging
    require_nested :MiddlewareServer
    require_nested :RefreshParser
    require_nested :RefreshWorker
    require_nested :Refresher

    include AuthenticationMixin
    include ::HawkularUtilsMixin

    DEFAULT_PORT = 80
    default_value_for :port, DEFAULT_PORT

    has_many :middleware_domains, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_servers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_deployments, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_datasources, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_messagings, :foreign_key => :ems_id, :dependent => :destroy

    attr_accessor :client

    def verify_credentials(_auth_type = nil, options = {})
      begin
        # As the connect will only give a handle
        # we verify the credentials via an actual operation
        connect(options).inventory.list_feeds
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

      true
    end

    def validate_authentication_status
      {:available => true, :message => nil}
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

    def machine_id(feed)
      os_resource_for(feed).try(:properties).try { |prop| prop['Machine Id'] }
    end

    def os_resource_for(feed)
      with_provider_connection do |connection|
        os = os_for(feed)
        unless os.nil?
          os_resources = connection.inventory.list_resources_for_type(os.path, true)
          unless os_resources.nil? || os_resources.empty?
            return os_resources.first
          end
          $mw_log.warn "Found no OS resources for resource type #{os.path}"
        end
        nil
      end
    end

    def os_for(feed)
      with_provider_connection do |connection|
        resource_types = connection.inventory.list_resource_types(hawk_escape_id(feed))
        os_types = resource_types.select { |item| item.id.include? 'Operating System' }
        unless os_types.nil? || os_types.empty?
          return os_types.first
        end

        $mw_log.warn "Found no OS resource types for feed #{feed}"
        nil
      end
    end

    def eaps(feed)
      with_provider_connection do |connection|
        path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id          => hawk_escape_id(feed),
                                                        :resource_type_id => hawk_escape_id('WildFly Server'))
        connection.inventory.list_resources_for_type(path.to_s, :fetch_properties => true)
      end
    end

    def domains(feed)
      with_provider_connection do |connection|
        path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id          => hawk_escape_id(feed),
                                                        :resource_type_id => hawk_escape_id('Domain Host'))
        host_controllers = connection.inventory.list_resources_for_type(path.to_s, :fetch_properties => true)

        # filter only the domain controllers
        host_controllers.select { |host_controller| host_controller.properties['Is Domain Controller'] == 'true' }
      end
    end

    def server_groups(feed)
      with_provider_connection do |connection|
        path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id          => hawk_escape_id(feed),
                                                        :resource_type_id => hawk_escape_id('Domain Server Group'))
        connection.inventory.list_resources_for_type(path.to_s, :fetch_properties => true)
      end
    end

    def jdbc_drivers(feed)
      with_provider_connection do |connection|
        path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id          => hawk_escape_id(feed),
                                                        :resource_type_id => hawk_escape_id('JDBC Driver'))
        connection.inventory.list_resources_for_type(path.to_s, :fetch_properties => true)
      end
    end

    def child_resources(resource_path, recursive = false)
      with_provider_connection do |connection|
        connection.inventory.list_child_resources(resource_path, recursive)
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

    def start_middleware_domain_server(ems_ref)
      run_generic_operation(:Start, ems_ref)
    end

    def stop_middleware_domain_server(ems_ref)
      run_generic_operation(:Stop, ems_ref)
    end

    def restart_middleware_server(ems_ref)
      run_generic_operation(:Shutdown, ems_ref, :restart => true)
    end

    def restart_middleware_domain_server(ems_ref)
      run_generic_operation(:Restart, ems_ref)
    end

    def kill_middleware_domain_server(ems_ref)
      run_generic_operation(:Kill, ems_ref)
    end

    def shutdown_middleware_server(ems_ref, params)
      timeout = params[:timeout] || 0
      run_generic_operation(:Shutdown, ems_ref, :restart => false, :timeout => timeout)
    end

    def suspend_middleware_server(ems_ref, params)
      timeout = params[:timeout] || 0
      run_generic_operation(:Suspend, ems_ref, :timeout => timeout)
    end

    def resume_middleware_server(ems_ref)
      run_generic_operation(:Resume, ems_ref)
    end

    def create_jdr_report(ems_ref)
      run_generic_operation(:JDR, ems_ref)
    end

    def self.raw_alerts_connect(hostname, port, username, password)
      require 'hawkular_all'
      url = URI::HTTP.build(:host => hostname, :port => port.to_i, :path => '/hawkular/alerts').to_s
      credentials = {
        :username => username,
        :password => password
      }
      ::Hawkular::Alerts::AlertsClient.new(url, credentials)
    end

    def add_middleware_datasource(ems_ref, hash)
      with_provider_connection do |connection|
        datasource_data = {
          :resourcePath   => ems_ref.to_s,
          :datasourceName => hash[:datasource]["datasourceName"],
          :xaDatasource   => hash[:datasource]["xaDatasource"],
          :jndiName       => hash[:datasource]["jndiName"],
          :driverName     => hash[:datasource]["driverName"],
          :driverClass    => hash[:datasource]["driverClass"],
          :connectionUrl  => hash[:datasource]["connectionUrl"],
          :userName       => hash[:datasource]["userName"],
          :password       => hash[:datasource]["password"],
          :securityDomain => hash[:datasource]["securityDomain"]
        }

        connection.operations(true).add_datasource(datasource_data) do |on|
          on.success do |data|
            _log.debug "Success on websocket-operation #{data}"
            emit_middleware_notification(:mw_op_success, 'Add Datasource', datasource_data[:datasourceName], ems_ref)
          end
          on.failure do |error|
            _log.error 'error callback was called, reason: ' + error.to_s
            emit_middleware_notification(:mw_op_failure, 'Add Datasource', datasource_data[:datasourceName], ems_ref)
          end
        end
      end
    end

    def add_middleware_deployment(ems_ref, hash)
      with_provider_connection do |connection|
        deployment_data = {
          :enabled               => hash[:file]["enabled"],
          :force_deploy          => hash[:file]["force_deploy"],
          :destination_file_name => hash[:file]["runtime_name"] || hash[:file]["file"].original_filename,
          :binary_content        => hash[:file]["file"].read,
          :resource_path         => ems_ref.to_s
        }

        connection.operations(true).add_deployment(deployment_data) do |on|
          on.success do |data|
            _log.debug "Success on websocket-operation #{data}"
            emit_middleware_notification(:mw_op_success, 'Deploy', deployment_data[:destination_file_name], ems_ref)
          end
          on.failure do |error|
            _log.error 'error callback was called, reason: ' + error.to_s
            emit_middleware_notification(:mw_op_failure, 'Deploy', deployment_data[:destination_file_name], ems_ref)
          end
        end
      end
    end

    def undeploy_middleware_deployment(ems_ref, deployment_name)
      with_provider_connection do |connection|
        deployment_data = {
          :resource_path   => ems_ref.to_s,
          :deployment_name => deployment_name,
          :remove_content  => true
        }

        connection.operations(true).undeploy(deployment_data) do |on|
          on.success do |data|
            _log.debug "Success on websocket-operation #{data}"
            emit_middleware_notification(:mw_op_success, 'Undeploy', deployment_name, ems_ref)
          end
          on.failure do |error|
            _log.error 'error callback was called, reason: ' + error.to_s
            emit_middleware_notification(:mw_op_failure, 'Undeploy', deployment_name, ems_ref)
          end
        end
      end
    end

    def disable_middleware_deployment(ems_ref, deployment_name)
      with_provider_connection do |connection|
        deployment_data = {
          :resource_path   => ems_ref.to_s,
          :deployment_name => deployment_name
        }

        connection.operations(true).disable_deployment(deployment_data) do |on|
          on.success do |data|
            _log.debug "Success on websocket-operation #{data}"
            emit_middleware_notification(:mw_op_success, 'Disable Deployment', deployment_name, ems_ref)
          end
          on.failure do |error|
            _log.error 'error callback was called, reason: ' + error.to_s
            emit_middleware_notification(:mw_op_failure, 'Disable Deployment', deployment_name, ems_ref)
          end
        end
      end
    end

    def enable_middleware_deployment(ems_ref, deployment_name)
      with_provider_connection do |connection|
        deployment_data = {
          :resource_path   => ems_ref.to_s,
          :deployment_name => deployment_name
        }

        connection.operations(true).enable_deployment(deployment_data) do |on|
          on.success do |data|
            _log.debug "Success on websocket-operation #{data}"
            emit_middleware_notification(:mw_op_success, 'Enable Deployment', deployment_name, ems_ref)
          end
          on.failure do |error|
            _log.error 'error callback was called, reason: ' + error.to_s
            emit_middleware_notification(:mw_op_failure, 'Enable Deployment', deployment_name, ems_ref)
          end
        end
      end
    end

    def restart_middleware_deployment(ems_ref, deployment_name)
      with_provider_connection do |connection|
        deployment_data = {
          :resource_path   => ems_ref.to_s,
          :deployment_name => deployment_name
        }

        connection.operations(true).restart_deployment(deployment_data) do |on|
          on.success do |data|
            _log.debug "Success on websocket-operation #{data}"
            emit_middleware_notification(:mw_op_success, 'Restart Deployment', deployment_name, ems_ref)
          end
          on.failure do |error|
            _log.error 'error callback was called, reason: ' + error.to_s
            emit_middleware_notification(:mw_op_failure, 'Restart Deployment', deployment_name, ems_ref)
          end
        end
      end
    end

    def add_middleware_jdbc_driver(ems_ref, hash)
      with_provider_connection do |connection|
        driver_data = {
          :driver_name          => hash[:driver]["driver_name"],
          :driver_jar_name      => hash[:driver]["driver_jar_name"] || hash[:driver]["file"].original_filename,
          :module_name          => hash[:driver]["module_name"],
          :driver_class         => hash[:driver]["driver_class"],
          :driver_major_version => hash[:driver]["driver_major_version"],
          :driver_minor_version => hash[:driver]["driver_minor_version"],
          :binary_content       => hash[:driver]["file"].read,
          :resource_path        => ems_ref.to_s
        }

        connection.operations(true).add_jdbc_driver(driver_data) do |on|
          on.success do |data|
            _log.debug "Success on websocket-operation #{data}"
            emit_middleware_notification(:mw_op_success, 'Add JDBC Driver', driver_data[:driver_name], ems_ref)
          end
          on.failure do |error|
            _log.error 'error callback was called, reason: ' + error.to_s
            emit_middleware_notification(:mw_op_failure, 'Add JDBC Driver', driver_data[:driver_name], ems_ref)
          end
        end
      end
    end

    def remove_middleware_datasource(ems_ref)
      run_specific_operation('RemoveDatasource', ems_ref)
    end

    def emit_middleware_notification(type, op_name, op_arg, ems_ref)
      Notification.create(:type => type, :options => {
        :op_name   => op_name,
        :op_arg    => op_arg,
        :mw_server => ems_ref
      })
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

    def build_availability_metric_id(feed_id, resource_id, metric_id)
      "AI~R~[#{feed_id}/#{resource_id}]~AT~#{metric_id}"
    end

    def self.update_alert(*args)
      operation = args[0][:operation]
      alert = args[0][:alert]
      miq_alert = {
        :id          => alert[:id],
        :enabled     => alert[:enabled],
        :description => alert[:description],
        :conditions  => alert[:expression],
        :based_on    => alert[:db]
      }
      MiddlewareManager.find_each { |m| m.alert_manager.process_alert(operation, miq_alert) }
    end

    def self.update_alert_profile(*args)
      alert_profile_arg = args[0]
      miq_alert_profile = {
        :id                  => alert_profile_arg[:profile_id],
        :old_alerts_ids      => alert_profile_arg[:old_alerts],
        :new_alerts_ids      => alert_profile_arg[:new_alerts],
        :old_assignments_ids => process_old_assignments_ids(alert_profile_arg[:old_assignments]),
        :new_assignments_ids => process_new_assignments_ids(alert_profile_arg[:new_assignments])
      }
      MiddlewareManager.find_each do |m|
        m.alert_profile_manager.process_alert_profile(alert_profile_arg[:operation], miq_alert_profile)
      end
    end

    def alert_manager
      @alert_manager ||= ManageIQ::Providers::Hawkular::MiddlewareManager::AlertManager.new(alerts_client)
    end

    def alert_profile_manager
      @alert_profile_manager ||= ManageIQ::Providers::Hawkular::MiddlewareManager::AlertProfileManager.new(alerts_client)
    end

    private

    # Trigger running a (Hawkular) operation on the
    # selected target server. This server is identified
    # by ems_ref, which in Hawkular terms is the
    # fully qualified resource path from Hawkular inventory
    #
    # this method execute an operation through ExecuteOperation request command.
    #
    def run_generic_operation(operation_name, ems_ref, parameters = {})
      the_operation = {
        :operationName => operation_name,
        :resourcePath  => ems_ref.to_s,
        :parameters    => parameters
      }
      run_operation(the_operation)
    end

    #
    # this method send a specific command to the server
    # with his own JSON. this doesn't use ExecuteOperation.
    #
    def run_specific_operation(operation_name, ems_ref, parameters = {})
      parameters[:resourcePath] = ems_ref.to_s
      run_operation(parameters, operation_name)
    end

    def run_operation(parameters, operation_name = nil)
      with_provider_connection do |connection|
        callback = proc do |on|
          on.success do |data|
            _log.debug "Success on websocket-operation #{data}"
            emit_middleware_notification(:mw_op_success, operation_name, parameters, ems_ref)
          end
          on.failure do |error|
            _log.error 'error callback was called, reason: ' + error.to_s
            emit_middleware_notification(:mw_op_failure, operation_name, parameters, ems_ref)
          end
        end
        operation_connection = connection.operations(true)
        if operation_name.nil?
          operation_connection.invoke_generic_operation(parameters, &callback)
        else
          operation_connection.invoke_specific_operation(parameters, operation_name, &callback)
        end
      end
    end

    def self.process_old_assignments_ids(old_assignments)
      old_assignments_ids = []
      unless old_assignments.empty?
        if old_assignments[0].class.name == "MiqEnterprise"
          MiddlewareManager.find_each { |m| m.middleware_servers.find_each { |eap| old_assignments_ids << eap.id } }
        else
          old_assignments_ids = old_assignments.collect(&:id)
        end
      end
      old_assignments_ids
    end

    def self.process_new_assignments_ids(new_assignments)
      new_assignments_ids = []
      unless new_assignments.nil? || new_assignments["assign_to"].nil?
        if new_assignments["assign_to"] == "enterprise"
          # Note that in this version the assign to enterprise is resolved at the moment of the assignment
          # In following iterations, enterprise assignment should be managed dynamically on the provider
          MiddlewareManager.find_each { |m| m.middleware_servers.find_each { |eap| new_assignments_ids << eap.id } }
        else
          new_assignments_ids = new_assignments["objects"]
        end
      end
      new_assignments_ids
    end
    private_class_method :process_old_assignments_ids, :process_new_assignments_ids
  end
end
